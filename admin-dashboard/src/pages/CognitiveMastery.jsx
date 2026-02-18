import { useState, useEffect } from 'react';
import MetricCard from '../components/cards/MetricCard';
import api from '../services/api';

export default function CognitiveMastery() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true);
        const result = await api.getCognitiveMastery();
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
          Error loading Cognitive Mastery data: {error}
        </div>
      </div>
    );
  }

  const summary = data?.summary;
  const nodes = data?.nodeBreakdown || [];

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Cognitive Mastery</h1>
        <p className="text-gray-500">
          Weak spot detection, capsule engagement, and retrieval outcomes — last 7 days
        </p>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <MetricCard
          title="Users Triggered"
          value={summary?.uniqueUsersTriggered}
          loading={loading}
          subtitle="Unique users with a weak spot detected"
        />
        <MetricCard
          title="Capsule Open Rate"
          value={summary?.capsuleOpenRate != null ? `${summary.capsuleOpenRate}%` : null}
          loading={loading}
          subtitle="Of triggered users who opened capsule"
        />
        <MetricCard
          title="Retrieval Pass Rate"
          value={summary?.retrievalPassRate != null ? `${summary.retrievalPassRate}%` : null}
          loading={loading}
          subtitle={`${summary?.totalRetrievals ?? 0} retrieval attempt${summary?.totalRetrievals !== 1 ? 's' : ''}`}
        />
        <MetricCard
          title="Top Node"
          value={summary?.mostTriggeredNode ?? '—'}
          loading={loading}
          subtitle="Most frequently triggered atlas node"
        />
      </div>

      {/* Per-Node Breakdown Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="p-4 border-b border-gray-100">
          <h2 className="text-base font-semibold text-gray-800">Node Breakdown</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            All atlas nodes with activity in the last 7 days
          </p>
        </div>

        {loading ? (
          <div className="p-8 text-center text-gray-400">Loading…</div>
        ) : nodes.length === 0 ? (
          <div className="p-8 text-center text-gray-400">No activity yet.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-100">
                <tr>
                  <th className="text-left px-4 py-3 text-gray-600 font-medium">Node</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Triggered</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Opened</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Completed</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Skipped</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Open Rate</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Completion Rate</th>
                  <th className="text-right px-4 py-3 text-gray-600 font-medium">Retrieval Pass</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {nodes.map((node) => (
                  <tr key={node.nodeId} className="hover:bg-gray-50 transition-colors">
                    <td className="px-4 py-3 text-gray-800 font-medium">
                      <div>{node.nodeName}</div>
                      <div className="text-xs text-gray-400 font-normal">{node.nodeId}</div>
                    </td>
                    <td className="px-4 py-3 text-right text-gray-700">{node.triggered}</td>
                    <td className="px-4 py-3 text-right text-gray-700">{node.opened}</td>
                    <td className="px-4 py-3 text-right text-gray-700">{node.completed}</td>
                    <td className="px-4 py-3 text-right text-gray-700">{node.skipped}</td>
                    <td className="px-4 py-3 text-right">
                      <span className={`font-medium ${node.openRate >= 50 ? 'text-green-600' : node.openRate >= 25 ? 'text-amber-600' : 'text-red-500'}`}>
                        {node.openRate}%
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <span className={`font-medium ${node.completionRate >= 60 ? 'text-green-600' : node.completionRate >= 30 ? 'text-amber-600' : 'text-red-500'}`}>
                        {node.opened > 0 ? `${node.completionRate}%` : '—'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      {node.retrievalAttempts > 0 ? (
                        <span className={`font-medium ${node.retrievalPassRate >= 67 ? 'text-green-600' : node.retrievalPassRate >= 40 ? 'text-amber-600' : 'text-red-500'}`}>
                          {node.retrievalPassRate}%
                          <span className="text-xs text-gray-400 font-normal ml-1">({node.retrievalAttempts})</span>
                        </span>
                      ) : (
                        <span className="text-gray-300">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {data && (
        <p className="text-xs text-gray-400 mt-4">
          Last updated: {new Date(data.generatedAt).toLocaleString()}
        </p>
      )}
    </div>
  );
}
