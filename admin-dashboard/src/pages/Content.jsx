import { useState, useEffect } from 'react';
import MetricCard from '../components/cards/MetricCard';
import api from '../services/api';

export default function Content() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true);
        const result = await api.getContent();
        setData(result.data);
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
          Error loading content data: {error}
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Content Quality</h1>
        <p className="text-gray-500">Monitor question accuracy and identify issues</p>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <MetricCard
          title="Questions with Stats"
          value={data?.totalQuestionsWithStats}
          loading={loading}
        />
        <MetricCard
          title="Avg Time (Easy)"
          value={data?.avgTimeByDifficulty?.easy ? `${data.avgTimeByDifficulty.easy}s` : '-'}
          loading={loading}
        />
        <MetricCard
          title="Avg Time (Medium)"
          value={data?.avgTimeByDifficulty?.medium ? `${data.avgTimeByDifficulty.medium}s` : '-'}
          loading={loading}
        />
        <MetricCard
          title="Avg Time (Hard)"
          value={data?.avgTimeByDifficulty?.hard ? `${data.avgTimeByDifficulty.hard}s` : '-'}
          loading={loading}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Low Accuracy Questions */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">
            Low Accuracy Questions (&lt;20%)
            <span className="ml-2 text-sm font-normal text-red-500">Needs Review</span>
          </h3>
          {loading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
            </div>
          ) : data?.lowAccuracyQuestions?.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No low accuracy questions found</p>
          ) : (
            <div className="overflow-x-auto max-h-[400px] overflow-y-auto">
              <table className="w-full">
                <thead className="sticky top-0 bg-white">
                  <tr className="border-b border-gray-100">
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Question ID</th>
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Subject</th>
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Accuracy</th>
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Times Shown</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {data?.lowAccuracyQuestions?.map((q) => (
                    <tr key={q.question_id} className="hover:bg-gray-50">
                      <td className="py-2 text-sm text-gray-800 font-mono">{q.question_id}</td>
                      <td className="py-2 text-sm text-gray-600">{q.subject}</td>
                      <td className="py-2 text-sm font-medium text-red-600">{q.accuracy_rate}%</td>
                      <td className="py-2 text-sm text-gray-600">{q.times_shown}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* High Accuracy Questions */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">
            High Accuracy Questions (&gt;95%)
            <span className="ml-2 text-sm font-normal text-yellow-500">May Be Too Easy</span>
          </h3>
          {loading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
            </div>
          ) : data?.highAccuracyQuestions?.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No high accuracy questions found</p>
          ) : (
            <div className="overflow-x-auto max-h-[400px] overflow-y-auto">
              <table className="w-full">
                <thead className="sticky top-0 bg-white">
                  <tr className="border-b border-gray-100">
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Question ID</th>
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Subject</th>
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Accuracy</th>
                    <th className="text-left py-2 text-xs font-medium text-gray-500">Times Shown</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {data?.highAccuracyQuestions?.map((q) => (
                    <tr key={q.question_id} className="hover:bg-gray-50">
                      <td className="py-2 text-sm text-gray-800 font-mono">{q.question_id}</td>
                      <td className="py-2 text-sm text-gray-600">{q.subject}</td>
                      <td className="py-2 text-sm font-medium text-green-600">{q.accuracy_rate}%</td>
                      <td className="py-2 text-sm text-gray-600">{q.times_shown}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
