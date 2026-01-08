# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default tseslint.config([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      ...tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      ...tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      ...tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default tseslint.config([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```
```
src/
├── components/               # Shared UI components (buttons, inputs, layout)
│   ├── ui/                   # Customized shadcn/ui components
│   ├── layout/               # App layout: navbar, sidebar, etc.
│   └── table/                # Custom TanStack Table components
│
├── features/                 # Domain-based structure
│   ├── users/
│   │   ├── components/       # User-specific UI (e.g. UserForm, UserCard)
│   │   ├── pages/            # Page components (Create, List, Detail, Edit)
│   │   │   ├── UserList.tsx
│   │   │   ├── UserCreate.tsx
│   │   │   ├── UserDetail.tsx
│   │   │   └── UserEdit.tsx
│   │   ├── api.ts            # API functions (axios/fetch)
│   │   ├── hooks.ts          # React Query hooks (useGetUsers, etc.)
│   │   ├── schema.ts         # Zod/Yup validation schemas
│   │   └── types.ts          # TypeScript interfaces
│   └── products/
│       └── (same structure as users)
│
├── routes/                   # React Router route definitions
│   └── AppRoutes.tsx         # All routes and nested routing
│
├── lib/                      # Reusable utility functions
│   ├── api.ts                # Axios instance or fetch wrapper
│   ├── queryClient.ts        # TanStack QueryClient setup
│   └── cn.ts                 # Class name utility (shadcn)
│
├── styles/                   # Global styles
│   └── globals.css
│
├── types/                    # Global/shared types
│   └── index.ts
│
├── App.tsx                   # App root component
├── main.tsx                  # ReactDOM render + QueryClientProvider, etc.
└── vite.config.ts            # Vite config

```
```
features/users/

features/
└── users/
    ├── pages/
    │   ├── UserList.tsx       # Uses TanStack Table to show users
    │   ├── UserCreate.tsx     # Form with validation
    │   ├── UserDetail.tsx     # View single user
    │   └── UserEdit.tsx       # Same form as create, pre-filled
    ├── components/
    │   └── UserForm.tsx
    ├── api.ts                 # axios.get('/users'), etc.
    ├── hooks.ts               # useGetUsers(), useCreateUser()
    ├── schema.ts              # Zod schema for form validation
    ├── types.ts               # User type/interface

```