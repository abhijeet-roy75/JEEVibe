import { useState, useEffect } from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import MetricCard from '../components/cards/MetricCard';
import api from '../services/api';

const COLORS = {
  mastered: '#10b981',
  growing: '#f59e0b',
  focus: '#ef4444'
};

export default function Learning() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true);
        const result = await api.getLearning();
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
          Error loading learning data: {error}
        </div>
      </div>
    );
  }

  const masteryData = data?.masteryProgression ? [
    { name: 'Mastered (80%+)', value: data.masteryProgression.mastered, color: COLORS.mastered },
    { name: 'Growing (40-79%)', value: data.masteryProgression.growing, color: COLORS.growing },
    { name: 'Focus (<40%)', value: data.masteryProgression.focus, color: COLORS.focus },
  ] : [];

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Learning Outcomes</h1>
        <p className="text-gray-500">Track student progress and mastery</p>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <MetricCard
          title="Students with Progress"
          value={data?.totalStudentsWithProgress}
          loading={loading}
        />
        <MetricCard
          title="Avg Theta Improvement"
          value={data?.avgThetaImprovement?.toFixed(2)}
          loading={loading}
        />
        <MetricCard
          title="Students Improving"
          value={`${data?.percentImproving || 0}%`}
          loading={loading}
        />
        <MetricCard
          title="Mastered Students"
          value={data?.masteryProgression?.mastered}
          loading={loading}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Mastery Distribution */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Mastery Distribution</h3>
          {loading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
            </div>
          ) : (
            <div className="flex items-center">
              <ResponsiveContainer width="60%" height={250}>
                <PieChart>
                  <Pie
                    data={masteryData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={100}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {masteryData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
              <div className="flex-1 space-y-3">
                {masteryData.map((item) => (
                  <div key={item.name} className="flex items-center gap-3">
                    <div className="w-4 h-4 rounded-full" style={{ backgroundColor: item.color }}></div>
                    <div>
                      <div className="text-sm font-medium text-gray-800">{item.name}</div>
                      <div className="text-lg font-bold text-gray-800">{item.value}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Most Common Focus Chapters */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Most Common Focus Chapters</h3>
          {loading ? (
            <div className="h-64 flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
            </div>
          ) : (
            <div className="space-y-3 max-h-[300px] overflow-y-auto">
              {data?.mostCommonFocusChapters?.length === 0 ? (
                <p className="text-gray-500 text-center py-8">No focus chapters found</p>
              ) : (
                data?.mostCommonFocusChapters?.map((item, index) => (
                  <div key={item.chapter} className="flex items-center justify-between py-2 border-b border-gray-100 last:border-0">
                    <div className="flex items-center gap-3">
                      <span className="text-sm font-medium text-gray-400 w-6">#{index + 1}</span>
                      <span className="text-sm text-gray-800">{item.chapter.replace(/_/g, ' ')}</span>
                    </div>
                    <span className="text-sm font-medium text-red-600">{item.count} students</span>
                  </div>
                ))
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
