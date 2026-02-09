import { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { format } from 'date-fns';
import MetricCard from '../components/cards/MetricCard';
import api from '../services/api';
import { BUILD_TIMESTAMP } from '../version';

export default function Dashboard() {
  const [health, setHealth] = useState(null);
  const [engagement, setEngagement] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true);
        const [healthData, engagementData] = await Promise.all([
          api.getDailyHealth(),
          api.getEngagement()
        ]);
        setHealth(healthData.data);
        setEngagement(engagementData.data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, []);

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
          Error loading dashboard: {error}
        </div>
      </div>
    );
  }

  const featureData = engagement ? [
    { name: 'Daily Quiz', value: engagement.featureUsage?.daily_quiz || 0 },
    { name: 'Snap Solve', value: engagement.featureUsage?.snap_solve || 0 },
    { name: 'AI Tutor', value: engagement.featureUsage?.ai_tutor || 0 },
    { name: 'Chapter Practice', value: engagement.featureUsage?.chapter_practice || 0 },
  ] : [];

  return (
    <div className="p-6">
      <div className="mb-6 flex justify-between items-start">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Daily Health</h1>
          <p className="text-gray-500">Overview of key metrics for today</p>
        </div>
        <div className="text-right">
          <div className="text-xs text-gray-400">Last deployed</div>
          <div className="text-sm font-medium text-gray-600">
            {format(new Date(BUILD_TIMESTAMP), 'MMM dd, yyyy HH:mm')}
          </div>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <MetricCard
          title="DAU"
          value={health?.dau}
          change={health?.dauChange}
          loading={loading}
        />
        <MetricCard
          title="New Signups"
          value={health?.newSignups}
          loading={loading}
        />
        <MetricCard
          title="Quiz Completion"
          value={health?.quizCompletionRate ? `${Math.round(health.quizCompletionRate * 100)}%` : '-'}
          loading={loading}
        />
        <MetricCard
          title="At Risk Users"
          value={health?.atRiskUsers}
          alert={health?.atRiskUsers > 10}
          loading={loading}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* DAU Trend */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">DAU Trend (7 days)</h3>
          {loading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={health?.dauTrend || []}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis
                  dataKey="date"
                  tickFormatter={(value) => value.slice(5)} // Show MM-DD
                  fontSize={12}
                />
                <YAxis fontSize={12} />
                <Tooltip />
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke="#3b82f6"
                  strokeWidth={2}
                  dot={{ fill: '#3b82f6' }}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Feature Usage */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Feature Usage (7 days)</h3>
          {loading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={featureData} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis type="number" fontSize={12} />
                <YAxis type="category" dataKey="name" fontSize={12} width={100} />
                <Tooltip />
                <Bar dataKey="value" fill="#3b82f6" radius={[0, 4, 4, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Active Users</h3>
          <p className="text-3xl font-bold text-primary-600">{engagement?.activeUsers || '-'}</p>
          <p className="text-sm text-gray-500">Last 7 days</p>
        </div>
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Avg Questions/User</h3>
          <p className="text-3xl font-bold text-primary-600">{engagement?.avgQuestionsPerUser || '-'}</p>
          <p className="text-sm text-gray-500">Total questions per active user</p>
        </div>
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-2">Total Users</h3>
          <p className="text-3xl font-bold text-primary-600">{health?.totalUsers || '-'}</p>
          <p className="text-sm text-gray-500">All registered users</p>
        </div>
      </div>
    </div>
  );
}
