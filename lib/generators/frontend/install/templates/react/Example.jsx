import { useState } from 'react'

import reactSvg from '/assets/react.svg'
import viteRubySvg from '/assets/vite_ruby.svg'

import cs from './Example.module.css'

export default function ExamplePage({ name }) {
  const [count, setCount] = useState(0)

  return (
    <>
      <div className={cs.root}>
        <h1 className={cs.h1}>Hello {name}!</h1>

        <div>
          <a href="https://vite-ruby.netlify.app" target="_blank">
            <img
              className={`${cs.logo} ${cs.vite}`}
              src={viteRubySvg}
              alt="Vite Ruby logo"
            />
          </a>
          <a href="https://react.dev" target="_blank">
            <img
              className={`${cs.logo} ${cs.react}`}
              src={reactSvg}
              alt="React logo"
            />
          </a>
        </div>

        <h2 className={cs.h2}>Vite Ruby + React</h2>

        <div className="card">
          <button
            className={cs.button}
            onClick={() => setCount((count) => count + 1)}
          >
            count is {count}
          </button>
          <p>
            Edit <code>app/frontend/pages/Example.jsx</code> and save to
            test HMR
          </p>
        </div>
        <p className={cs.readTheDocs}>
          Click on the Vite Ruby, and React logos to learn more
        </p>
      </div>
    </>
  )
}
