import { Routes, Route } from 'react-router-dom';
import Layout from './components/layout/Layout';
import ProtectedRoute from './components/auth/ProtectedRoute';
import LoginPage from './components/auth/LoginPage';
import Dashboard from './pages/Dashboard';
import Engagement from './pages/Engagement';
import Learning from './pages/Learning';
import Users from './pages/Users';
import UserDetail from './pages/UserDetail';
import Content from './pages/Content';
import Alerts from './pages/Alerts';
import Teachers from './pages/Teachers';
import TeacherDetail from './pages/TeacherDetail';

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
        <Route path="/users/:userId" element={<UserDetail />} />
        <Route path="/content" element={<Content />} />
        <Route path="/alerts" element={<Alerts />} />
        <Route path="/teachers" element={<Teachers />} />
        <Route path="/teachers/:teacherId" element={<TeacherDetail />} />
      </Route>
    </Routes>
  );
}

export default App;
