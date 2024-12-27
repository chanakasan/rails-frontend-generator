import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// import App from "../pages/Example"

const App = () => <div className="text-2xl text-red-500">From React!!!</div>

const container = document.getElementById('root')
console.log("root", container)

createRoot(container!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
