import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { formatDistanceToNow } from 'date-fns';
import api from '../services/api';

function TierBadge({ tier }) {
  const colors = {
    free: 'bg-gray-100 text-gray-700',
    pro: 'bg-blue-100 text-blue-700',
    ultra: 'bg-purple-100 text-purple-700'
  };

  return (
    <span className={`px-2 py-1 rounded-full text-xs font-medium ${colors[tier] || colors.free}`}>
      {tier?.toUpperCase() || 'FREE'}
    </span>
  );
}

export default function Users() {
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [total, setTotal] = useState(0);

  useEffect(() => {
    async function fetchUsers() {
      try {
        setLoading(true);
        const result = await api.getUsers({ filter, search, limit: 50 });
        setUsers(result.data.users);
        setTotal(result.data.total);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }
    fetchUsers();
  }, [filter, search]);

  const handleSearchChange = (e) => {
    setSearch(e.target.value);
  };

  const formatLastActive = (date) => {
    if (!date) return 'Never';
    try {
      return formatDistanceToNow(new Date(date), { addSuffix: true });
    } catch {
      return 'Unknown';
    }
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Users</h1>
        <p className="text-gray-500">View and search all registered users</p>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4 mb-6">
        <input
          type="text"
          placeholder="Search by name, email, or phone..."
          value={search}
          onChange={handleSearchChange}
          className="flex-1 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
        />
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent bg-white"
        >
          <option value="all">All Users</option>
          <option value="active">Active (last 3 days)</option>
          <option value="at-risk">At Risk (inactive 3+ days)</option>
          <option value="pro">Pro Tier</option>
          <option value="ultra">Ultra Tier</option>
        </select>
      </div>

      {/* Results count */}
      <div className="mb-4 text-sm text-gray-500">
        Showing {users.length} of {total} users
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700 mb-4">
          {error}
        </div>
      )}

      {/* Users Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100">
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Tier</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Streak</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Questions</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Last Active</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">Percentile</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto"></div>
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center text-gray-500">
                    No users found
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr
                    key={user.uid}
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => navigate(`/users/${user.uid}`)}
                  >
                    <td className="px-6 py-4">
                      <div>
                        <div className="font-medium text-gray-800">
                          {user.firstName} {user.lastName}
                        </div>
                        <div className="text-sm text-gray-500">{user.email || user.phone}</div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <TierBadge tier={user.tier} />
                    </td>
                    <td className="px-6 py-4 text-gray-800">
                      {user.currentStreak} days
                    </td>
                    <td className="px-6 py-4 text-gray-800">
                      {user.totalQuestions}
                    </td>
                    <td className="px-6 py-4 text-gray-500 text-sm">
                      {formatLastActive(user.lastActive)}
                    </td>
                    <td className="px-6 py-4">
                      <span className={`font-medium ${
                        user.overallPercentile >= 80 ? 'text-green-600' :
                        user.overallPercentile >= 40 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {user.overallPercentile}%
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
