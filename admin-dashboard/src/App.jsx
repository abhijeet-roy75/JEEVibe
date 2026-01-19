import { Routes, Route } from 'react-router-dom';
import Layout from './components/layout/Layout';
import ProtectedRoute from './components/auth/ProtectedRoute';
import LoginPage from './components/auth/LoginPage';
import Dashboard from './pages/Dashboard';
import Engagement from './pages/Engagement';
import Learning from './pages/Learning';
import Users from './pages/Users';
import Content from './pages/Content';
import Alerts from './pages/Alerts';

function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route path="/" element={<Dashboard />} />
        <Route path="/engagement" element={<Engagement />} />
        <Route path="/learning" element={<Learning />} />
        <Route path="/users" element={<Users />} />
        <Route path="/content" element={<Content />} />
        <Route path="/alerts" element={<Alerts />} />
      </Route>
    </Routes>
  );
}

export default App;
