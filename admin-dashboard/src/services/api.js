import { auth } from './firebase';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

/**
 * Make authenticated API request
 */
async function fetchWithAuth(endpoint, options = {}) {
  const user = auth.currentUser;
  if (!user) {
    throw new Error('Not authenticated');
  }

  const token = await user.getIdToken();

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `API error: ${response.status}`);
  }

  return response.json();
}

export const api = {
  // Health metrics
  getDailyHealth: () => fetchWithAuth('/api/admin/metrics/daily-health'),

  // Engagement metrics
  getEngagement: () => fetchWithAuth('/api/admin/metrics/engagement'),

  // Learning metrics
  getLearning: () => fetchWithAuth('/api/admin/metrics/learning'),

  // Content metrics
  getContent: () => fetchWithAuth('/api/admin/metrics/content'),

  // Users
  getUsers: (params = {}) => {
    const searchParams = new URLSearchParams(params);
    return fetchWithAuth(`/api/admin/users?${searchParams}`);
  },

  getUserDetails: (userId) => fetchWithAuth(`/api/admin/users/${userId}`),

  // Alerts
  getAlerts: () => fetchWithAuth('/api/admin/alerts'),

  // Teachers
  getTeachers: (params = {}) => {
    const searchParams = new URLSearchParams(params);
    return fetchWithAuth(`/api/teachers?${searchParams}`);
  },

  getTeacher: (teacherId) => fetchWithAuth(`/api/teachers/${teacherId}`),

  getTeacherStudents: (teacherId, params = {}) => {
    const searchParams = new URLSearchParams(params);
    return fetchWithAuth(`/api/teachers/${teacherId}/students?${searchParams}`);
  },

  createTeacher: (teacherData) => fetchWithAuth('/api/teachers', {
    method: 'POST',
    body: JSON.stringify(teacherData),
  }),

  updateTeacher: (teacherId, updates) => fetchWithAuth(`/api/teachers/${teacherId}`, {
    method: 'PATCH',
    body: JSON.stringify(updates),
  }),

  deactivateTeacher: (teacherId) => fetchWithAuth(`/api/teachers/${teacherId}`, {
    method: 'DELETE',
  }),
};

export default api;
