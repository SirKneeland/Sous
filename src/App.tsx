import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { DemoPage } from './pages/DemoPage'
import './styles/global.css'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/demo" element={<DemoPage />} />
        <Route path="*" element={<Navigate to="/demo" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
