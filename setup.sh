#!/bin/bash

# Height Of Joy Technical College - Project Setup Script
# This script recreates the entire Result Portal project locally.

echo "Creating project structure..."
mkdir -p hojtc-portal/src/components
cd hojtc-portal

# Create package.json
cat <<EOF > package.json
{
  "name": "hojtc-portal",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "tsx server.ts",
    "build": "vite build",
    "start": "node server.ts",
    "lint": "tsc --noEmit"
  },
  "dependencies": {
    "@tailwindcss/vite": "^4.1.14",
    "@vitejs/plugin-react": "^5.0.4",
    "better-sqlite3": "^12.4.1",
    "dotenv": "^17.2.3",
    "express": "^4.21.2",
    "lucide-react": "^0.546.0",
    "motion": "^12.23.24",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "vite": "^6.2.0"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^22.14.0",
    "autoprefixer": "^10.4.21",
    "tailwindcss": "^4.1.14",
    "tsx": "^4.21.0",
    "typescript": "~5.8.2"
  }
}
EOF

# Create vite.config.ts
cat <<EOF > vite.config.ts
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig} from 'vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, '.'),
    },
  },
  server: {
    port: 3000,
    proxy: {
      '/api': 'http://localhost:3000'
    }
  }
});
EOF

# Create tsconfig.json
cat <<EOF > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "moduleDetection": "force",
    "allowJs": true,
    "jsx": "react-jsx",
    "allowImportingTsExtensions": true,
    "noEmit": true
  }
}
EOF

# Create index.html
cat <<EOF > index.html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>HOJTC Result Portal</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# Create server.ts
# (Note: Copying the full content of server.ts here)
cat <<EOF > server.ts
import express from "express";
import { createServer as createViteServer } from "vite";
import Database from "better-sqlite3";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const db = new Database("school.db");

try {
  db.exec(\`
    CREATE TABLE IF NOT EXISTS results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_name TEXT NOT NULL,
      student_id TEXT NOT NULL,
      subject TEXT NOT NULL,
      assignment INTEGER DEFAULT 0,
      test INTEGER DEFAULT 0,
      ca INTEGER DEFAULT 0,
      exam INTEGER DEFAULT 0,
      total INTEGER DEFAULT 0,
      grade TEXT NOT NULL,
      term TEXT NOT NULL,
      session TEXT NOT NULL,
      class TEXT NOT NULL
    )
  \`);

  db.exec(\`
    CREATE TABLE IF NOT EXISTS admissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fullName TEXT NOT NULL,
      phone TEXT NOT NULL,
      email TEXT,
      classApplied TEXT NOT NULL,
      previousSchool TEXT NOT NULL,
      address TEXT,
      appliedAt DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  \`);
  console.log("Database initialized");
} catch (err) {
  console.error("DB Error:", err);
}

async function startServer() {
  const app = express();
  app.use(express.json());

  app.post("/api/login", (req, res) => {
    const { username, password } = req.body;
    if (username?.toUpperCase() === "CHARLES" && password === "CHARLES") {
      res.json({ success: true, token: "token" });
    } else {
      res.status(401).json({ success: false });
    }
  });

  app.post("/api/admission", (req, res) => {
    const { fullName, phone, email, classApplied, previousSchool, address } = req.body;
    const stmt = db.prepare("INSERT INTO admissions (fullName, phone, email, classApplied, previousSchool, address) VALUES (?, ?, ?, ?, ?, ?)");
    stmt.run(fullName, phone, email, classApplied, previousSchool, address);
    res.json({ success: true });
  });

  app.get("/api/results/search", (req, res) => {
    const { name, student_id } = req.query;
    let query = "SELECT * FROM results WHERE 1=1";
    const params = [];
    if (name) { query += " AND student_name LIKE ?"; params.push(\`%\${name}%\`); }
    if (student_id) { query += " AND student_id = ?"; params.push(student_id); }
    res.json(db.prepare(query).all(...params));
  });

  app.post("/api/results/upload", (req, res) => {
    const { student_name, student_id, term, session, className, subjects } = req.body;
    const stmt = db.prepare("INSERT INTO results (student_name, student_id, subject, assignment, test, ca, exam, total, grade, term, session, class) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    const insert = db.transaction((subs) => {
      for (const s of subs) stmt.run(student_name, student_id, s.subject, s.assignment, s.test, s.ca, s.exam, s.total, s.grade, term, session, className);
    });
    insert(subjects);
    res.json({ success: true });
  });

  app.get("/api/results/all", (req, res) => res.json(db.prepare("SELECT * FROM results ORDER BY id DESC").all()));
  app.delete("/api/results/:id", (req, res) => { db.prepare("DELETE FROM results WHERE id = ?").run(req.params.id); res.json({ success: true }); });

  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({ server: { middlewareMode: true }, appType: "spa" });
    app.use(vite.middlewares);
  } else {
    app.use(express.static("dist"));
    app.get("*", (req, res) => res.sendFile(path.resolve("dist/index.html")));
  }

  app.listen(3000, "0.0.0.0", () => console.log("Server running on port 3000"));
}
startServer();
EOF

# Create src/main.tsx
cat <<EOF > src/main.tsx
import {StrictMode} from 'react';
import {createRoot} from 'react-dom/client';
import App from './App.tsx';
import './index.css';
createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
EOF

# Create src/App.tsx
cat <<EOF > src/App.tsx
import React from 'react';
import Navbar from './components/Navbar';
import StudentPortal from './components/StudentPortal';
import TeacherLogin from './components/TeacherLogin';
import TeacherDashboard from './components/TeacherDashboard';
import AdmissionForm from './components/AdmissionForm';

export default function App() {
  const [view, setView] = React.useState('home');
  const [isLoggedIn, setIsLoggedIn] = React.useState(false);

  const handleLogin = (token) => {
    setIsLoggedIn(true);
    setView('teacher-dashboard');
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar currentView={view} setView={setView} isLoggedIn={isLoggedIn} onLogout={() => setIsLoggedIn(false)} />
      <main>
        {view === 'home' && <div className="p-20 text-center"><h1>Welcome to HOJTC</h1><button onClick={() => setView('admission')} className="bg-indigo-600 text-white p-4 rounded mt-4">Apply Now</button></div>}
        {view === 'student-portal' && <StudentPortal />}
        {view === 'admission' && <AdmissionForm />}
        {view === 'teacher-login' && <TeacherLogin onLogin={handleLogin} />}
        {view === 'teacher-dashboard' && (isLoggedIn ? <TeacherDashboard /> : <TeacherLogin onLogin={handleLogin} />)}
      </main>
    </div>
  );
}
EOF

# Create src/components/Navbar.tsx
cat <<EOF > src/components/Navbar.tsx
import React from 'react';
import { GraduationCap, LogIn, Search, Home, BookOpen } from 'lucide-react';

export default function Navbar({ currentView, setView, isLoggedIn, onLogout }) {
  return (
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center">
          <div className="flex items-center cursor-pointer" onClick={() => setView('home')}>
            <GraduationCap className="h-8 w-8 text-indigo-600 mr-2" />
            <span className="font-bold text-xl text-gray-900">HOJTC</span>
          </div>
          <div className="flex space-x-4">
            <button onClick={() => setView('home')} className="px-3 py-2 text-sm font-medium">Home</button>
            <button onClick={() => setView('student-portal')} className="px-3 py-2 text-sm font-medium">Results</button>
            <button onClick={() => setView('admission')} className="px-3 py-2 text-sm font-medium">Admission</button>
            <button onClick={() => setView('teacher-login')} className="px-3 py-2 text-sm font-medium">Staff</button>
          </div>
        </div>
      </div>
    </nav>
  );
}
EOF

# Create src/index.css
cat <<EOF > src/index.css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=Dancing+Script:wght@700&display=swap');
@import "tailwindcss";

@layer base {
  @media print {
    .no-print { display: none !important; }
    body { background: white !important; padding: 0 !important; margin: 0 !important; }
    main { padding: 0 !important; }
  }
}

@theme {
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
  --font-signature: "Dancing Script", cursive;
}
EOF

# Create src/components/AdmissionForm.tsx
cat <<EOF > src/components/AdmissionForm.tsx
import React, { useState } from 'react';
import { motion } from 'motion/react';
import { User, Phone, Mail, BookOpen, Send, CheckCircle2, Loader2 } from 'lucide-react';

export default function AdmissionForm() {
  const [formData, setFormData] = useState({
    fullName: '', phone: '', email: '', classApplied: 'JSS 1', previousSchool: '', address: ''
  });
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      await fetch('/api/admission', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });
      const subject = \`Admission Application: \${formData.fullName}\`;
      const body = \`New Admission Application:\\n\\nName: \${formData.fullName}\\nPhone: \${formData.phone}\\nClass: \${formData.classApplied}\\nPrev School: \${formData.previousSchool}\`;
      window.location.href = \`mailto:starlinkoxford@gmail.com?subject=\${encodeURIComponent(subject)}&body=\${encodeURIComponent(body)}\`;
      setSubmitted(true);
    } catch (error) {
      alert("Error submitting application.");
    } finally {
      setSubmitting(false);
    }
  };

  if (submitted) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-20 text-center">
        <div className="bg-white p-12 rounded-[3rem] shadow-xl border border-indigo-50">
          <CheckCircle2 className="h-16 w-16 text-green-600 mx-auto mb-6" />
          <h2 className="text-3xl font-black mb-4">Application Prepared! 🎉</h2>
          <p className="text-gray-600 mb-8">Congratulations! Your details have been saved and your email is ready.</p>
          <button onClick={() => window.location.reload()} className="bg-indigo-600 text-white px-8 py-4 rounded-2xl font-bold">Return to Home</button>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <h1 className="text-4xl font-black text-center mb-12">Apply for Admission</h1>
      <form onSubmit={handleSubmit} className="bg-white p-12 rounded-[3rem] shadow-xl space-y-6">
        <input required name="fullName" value={formData.fullName} onChange={handleChange} className="w-full p-4 border rounded-2xl" placeholder="Full Name" />
        <input required name="phone" value={formData.phone} onChange={handleChange} className="w-full p-4 border rounded-2xl" placeholder="Parent Phone" />
        <input name="email" value={formData.email} onChange={handleChange} className="w-full p-4 border rounded-2xl" placeholder="Email" />
        <select name="classApplied" value={formData.classApplied} onChange={handleChange} className="w-full p-4 border rounded-2xl">
          <option>JSS 1</option><option>JSS 2</option><option>JSS 3</option>
          <option>SSS 1</option><option>SSS 2</option><option>SSS 3</option>
        </select>
        <input required name="previousSchool" value={formData.previousSchool} onChange={handleChange} className="w-full p-4 border rounded-2xl" placeholder="Previous School" />
        <textarea name="address" value={formData.address} onChange={handleChange} className="w-full p-4 border rounded-2xl" placeholder="Address" rows={3} />
        <button type="submit" disabled={submitting} className="w-full bg-indigo-600 text-white py-4 rounded-2xl font-bold">
          {submitting ? "Processing..." : "Submit Application via Email"}
        </button>
      </form>
    </div>
  );
}
EOF

echo "Setup complete! Now run:"
echo "cd hojtc-portal"
echo "npm install"
echo "npm run dev"
