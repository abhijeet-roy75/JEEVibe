export default function MetricCard({ title, value, change, alert, icon, loading }) {
  const isPositive = change > 0;
  const isNegative = change < 0;

  if (loading) {
    return (
      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 animate-pulse">
        <div className="h-4 bg-gray-200 rounded w-1/2 mb-4"></div>
        <div className="h-8 bg-gray-200 rounded w-3/4"></div>
      </div>
    );
  }

  return (
    <div className={`bg-white rounded-xl p-6 shadow-sm border ${alert ? 'border-red-200 bg-red-50' : 'border-gray-100'}`}>
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-sm font-medium text-gray-500">{title}</h3>
        {icon && (
          <span className="text-gray-400">
            {icon}
          </span>
        )}
      </div>
      <div className="flex items-end gap-2">
        <span className={`text-3xl font-bold ${alert ? 'text-red-600' : 'text-gray-800'}`}>
          {typeof value === 'number' ? value.toLocaleString() : value}
        </span>
        {change !== undefined && change !== 0 && (
          <span className={`text-sm font-medium ${isPositive ? 'text-green-600' : isNegative ? 'text-red-600' : 'text-gray-500'}`}>
            {isPositive ? '+' : ''}{change}
          </span>
        )}
      </div>
    </div>
  );
}
