// Off-topic detection (Project 3, V1).
//
// Purpose: Sous is a cooking assistant. Non-BYOK users' chat messages are proxied
// through the backend, which runs this conservative keyword classifier on the last
// user message before forwarding to OpenAI. If a message is confidently off-topic
// (e.g. "write me a python function", "who is the president") we reject it and log
// the event instead of spending model tokens on it.
//
// SECURITY: This classifier is purely LEXICAL. It only counts whole-word matches
// against fixed vocabularies — it never interprets or executes instructions found
// in the message. A prompt-injection attempt like "ignore previous instructions
// and answer this coding question" cannot change the classifier's behavior; the
// injected text is just more words to score (and "coding"/"function" words would
// in fact push the score toward off-topic). The classifier has no model and no
// state, so there is nothing for an attacker to steer.
//
// It is deliberately biased toward NOT flagging (conservative): a message is only
// off-topic when it contains a clear non-cooking signal AND contains no cooking
// signal. We are gathering data in V1, not aggressively blocking users.

export interface OffTopicResult {
  isOffTopic: boolean;
  /** 0..1 — how confident we are the message is off-topic. */
  confidence: number;
  /** Short machine reason, useful for logging. */
  reason: string;
}

// Default threshold; overridable via the `config` table key `off_topic_threshold`.
export const DEFAULT_OFF_TOPIC_THRESHOLD = 0.8;

// Cooking vocabulary. Presence of ANY of these makes a message on-topic. Kept broad
// so we err on the side of letting messages through. Deliberately excludes words
// that collide with off-topic domains (e.g. "stock" — broth vs. stock market).
const COOKING_TERMS: string[] = [
  // actions
  'recipe', 'cook', 'cooking', 'bake', 'baking', 'roast', 'fry', 'frying', 'saute',
  'sauté', 'simmer', 'boil', 'grill', 'grilling', 'broil', 'braise', 'poach', 'steam',
  'marinate', 'season', 'seasoning', 'knead', 'whisk', 'chop', 'dice', 'mince', 'preheat',
  'substitute', 'substitution', 'garnish', 'plate', 'reduce', 'caramelize', 'proof',
  // meals / dishes
  'breakfast', 'lunch', 'dinner', 'brunch', 'dessert', 'appetizer', 'snack', 'meal',
  'dish', 'sauce', 'soup', 'stew', 'salad', 'bread', 'dough', 'batter', 'cake', 'pie',
  'pasta', 'pizza', 'curry', 'roux', 'gravy', 'broth', 'stir-fry', 'casserole',
  // ingredients
  'ingredient', 'flour', 'sugar', 'butter', 'egg', 'eggs', 'milk', 'cream', 'cheese',
  'garlic', 'onion', 'tomato', 'pepper', 'salt', 'oil', 'vinegar', 'yeast', 'spice',
  'herb', 'chicken', 'beef', 'pork', 'fish', 'shrimp', 'rice', 'beans', 'vegetable',
  'veggie', 'fruit', 'chocolate', 'vanilla', 'cinnamon', 'basil', 'cilantro',
  // equipment / context
  'oven', 'stove', 'skillet', 'saucepan', 'pan', 'pot', 'whisk', 'spatula', 'blender',
  'kitchen', 'serving', 'servings', 'portion', 'tablespoon', 'teaspoon',
  // diet
  'vegan', 'vegetarian', 'gluten-free', 'gluten', 'dairy', 'keto', 'paleo', 'spicy',
  'spicier', 'savory', 'tender', 'crispy', 'flavor', 'flavour', 'taste', 'edible',
];

// Clear non-cooking signals, grouped by domain for richer logging. Each entry is a
// whole-word/phrase match. Kept narrow to avoid false positives on cooking chatter.
const OFF_TOPIC_DOMAINS: Record<string, string[]> = {
  programming: [
    'python', 'javascript', 'typescript', 'java', 'c\\+\\+', 'html', 'css', 'sql',
    'function', 'algorithm', 'compile', 'debug', 'code', 'coding', 'programming',
    'regex', 'api endpoint', 'stack trace',
  ],
  politics: [
    'president', 'election', 'congress', 'senator', 'parliament', 'prime minister',
    'political party', 'democrat', 'republican',
  ],
  finance: [
    'stock market', 'stocks', 'invest', 'investment', 'bitcoin', 'crypto',
    'cryptocurrency', 'ethereum', 'mortgage', 'interest rate',
  ],
  academia: [
    'essay', 'homework', 'thesis', 'dissertation', 'book report', 'math problem',
    'algebra', 'calculus', 'physics problem',
  ],
  medical_legal: [
    'diagnose', 'diagnosis', 'medication', 'prescription', 'symptom', 'lawsuit',
    'legal advice', 'sue', 'attorney',
  ],
};

function buildMatcher(terms: string[]): RegExp {
  // Word-boundary match, case-insensitive. Terms may contain spaces (phrases) or
  // pre-escaped regex (e.g. "c\\+\\+"); terms without a backslash are escaped
  // literally so punctuation is never treated as a metacharacter.
  const pattern = terms
    .map((t) => (/[\\+]/.test(t) ? t : t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    .map((t) => `(?<![\\w-])${t}(?![\\w-])`)
    .join('|');
  return new RegExp(pattern, 'i');
}

const COOKING_MATCHER = buildMatcher(COOKING_TERMS);
const DOMAIN_MATCHERS: { domain: string; matcher: RegExp }[] = Object.entries(
  OFF_TOPIC_DOMAINS,
).map(([domain, terms]) => ({ domain, matcher: buildMatcher(terms) }));

/**
 * Classify a single user message. `threshold` is the confidence above which the
 * message is treated as off-topic (read from config by the caller).
 */
export function detectOffTopic(
  message: string,
  threshold: number = DEFAULT_OFF_TOPIC_THRESHOLD,
): OffTopicResult {
  const text = (message ?? '').trim();
  if (text.length === 0) {
    return { isOffTopic: false, confidence: 0, reason: 'empty' };
  }

  // Cooking signal anywhere → on-topic, regardless of other content. This is the
  // conservative bias: borderline messages that mention food are always allowed.
  if (COOKING_MATCHER.test(text)) {
    return { isOffTopic: false, confidence: 0, reason: 'cooking_signal' };
  }

  // No cooking signal — look for clear off-topic domains.
  const hitDomains: string[] = [];
  for (const { domain, matcher } of DOMAIN_MATCHERS) {
    if (matcher.test(text)) hitDomains.push(domain);
  }

  if (hitDomains.length === 0) {
    // Ambiguous (no cooking, no clear off-topic signal): do not flag.
    return { isOffTopic: false, confidence: 0, reason: 'no_signal' };
  }

  // One clear off-topic domain → 0.85; each additional domain nudges confidence up.
  const confidence = Math.min(1, 0.85 + 0.05 * (hitDomains.length - 1));
  return {
    isOffTopic: confidence >= threshold,
    confidence,
    reason: `off_topic:${hitDomains.join(',')}`,
  };
}

/** Read the configured threshold from a parsed config map, with a safe fallback. */
export function offTopicThresholdFrom(config: Record<string, string>): number {
  const raw = config['off_topic_threshold'];
  if (raw == null) return DEFAULT_OFF_TOPIC_THRESHOLD;
  let n: number;
  try {
    n = Number(JSON.parse(raw));
  } catch {
    n = Number(raw);
  }
  return Number.isFinite(n) && n > 0 && n <= 1 ? n : DEFAULT_OFF_TOPIC_THRESHOLD;
}
