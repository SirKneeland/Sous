import SousCore

protocol PatchProposer {
    func propose(userText: String, recipe: Recipe) -> PatchSet
}
