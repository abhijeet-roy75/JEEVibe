import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { formatDistanceToNow, format } from 'date-fns';
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

function StatCard({ label, value, subtext }) {
  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      <div className="text-sm text-gray-500 mb-1">{label}</div>
      <div className="text-2xl font-bold text-gray-800">{value}</div>
      {subtext && <div className="text-xs text-gray-400 mt-1">{subtext}</div>}
    </div>
  );
}

function formatDuration(seconds) {
  if (!seconds) return '0s';
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  const remainingSeconds = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${remainingMinutes}m`;
  }
  if (minutes > 0) {
    return `${minutes}m`;
  }
  return `${remainingSeconds}s`;
}

function formatDate(date) {
  if (!date) return 'N/A';
  try {
    const d = date.toDate ? date.toDate() : new Date(date);
    return format(d, 'MMM dd, yyyy HH:mm');
  } catch {
    return 'N/A';
  }
}

function formatDateTime(dateString) {
  if (!dateString) return 'N/A';
  try {
    const d = new Date(dateString);
    return format(d, 'MMM dd, yyyy HH:mm');
  } catch {
    return 'N/A';
  }
}

export default function UserDetail() {
  const { userId } = useParams();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchUserDetails() {
      try {
        setLoading(true);
        const result = await api.getUserDetails(userId);
        setUser(result.data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }
    fetchUserDetails();
  }, [userId]);

  if (loading) {
    return (
      <div className="p-6 flex justify-center items-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
          {error}
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-6">
        <div className="text-gray-500">User not found</div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="mb-6">
        <Link to="/users" className="text-primary-600 hover:text-primary-700 text-sm mb-2 inline-block">
          ← Back to Users
        </Link>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-800">
              {user.profile.firstName} {user.profile.lastName}
            </h1>
            <p className="text-gray-500">{user.profile.email || user.profile.phone}</p>
          </div>
          <TierBadge tier={user.subscription.tier} />
        </div>
      </div>

      {/* Overview Stats */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-6">
        <StatCard
          label="Overall Percentile"
          value={`${user.progress.overallPercentile || 0}%`}
          subtext={`θ: ${user.progress.overallTheta?.toFixed(2) || 'N/A'}`}
        />
        <StatCard
          label="Overall Accuracy"
          value={`${user.progress.overallAccuracy || 0}%`}
          subtext="Correct answers"
        />
        <StatCard
          label="Total Questions"
          value={user.progress.totalQuestions}
          subtext={`${user.progress.quizzesCompleted} quizzes`}
        />
        <StatCard
          label="Current Streak"
          value={`${user.streak.current} days`}
          subtext={`Longest: ${user.streak.longest} days`}
        />
        <StatCard
          label="Last Active"
          value={
            user.profile.lastActive
              ? formatDistanceToNow(new Date(user.profile.lastActive), { addSuffix: true })
              : 'Never'
          }
          subtext={user.profile.isEnrolledInCoaching ? 'In coaching' : 'Self study'}
        />
      </div>

      {/* Initial Assessment */}
      {user.assessment && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Initial Assessment</h2>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <div className="text-sm text-gray-500">Completed</div>
              <div className="text-lg font-medium text-gray-800">
                {formatDate(user.assessment.completedAt)}
              </div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Score</div>
              <div className="text-lg font-medium text-gray-800">
                {user.assessment.score}/{user.assessment.totalQuestions}
              </div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Accuracy</div>
              <div className="text-lg font-medium text-gray-800">
                {(user.assessment.accuracy * 100).toFixed(1)}%
              </div>
            </div>
            <div>
              <div className="text-sm text-gray-500">Time Spent</div>
              <div className="text-lg font-medium text-gray-800">
                {formatDuration(user.assessment.timeSpentSeconds)}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Subject Performance */}
      {user.progress.thetaBySubject && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Subject Performance</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {Object.entries(user.progress.thetaBySubject).map(([subject, data]) => (
              <div key={subject} className="border border-gray-200 rounded-lg p-4">
                <div className="font-medium text-gray-800 mb-2 capitalize">{subject}</div>
                <div className="text-sm">
                  <div className="text-gray-500">Theta (θ)</div>
                  <div className="text-2xl font-bold text-gray-800 mt-1">
                    {data.theta?.toFixed(2) || 'N/A'}
                  </div>
                  {data.percentile && (
                    <div className="text-xs text-gray-500 mt-1">
                      {data.percentile}th percentile
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Daily Quizzes */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">
          Daily Quizzes ({user.dailyQuizzes?.length || 0})
        </h2>
        {user.dailyQuizzes && user.dailyQuizzes.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Date</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Score</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Accuracy</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Time</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {user.dailyQuizzes.slice(0, 10).map((quiz, idx) => (
                  <tr key={quiz.id || idx} className="hover:bg-gray-50">
                    <td className="py-2 px-3 text-sm">{formatDate(quiz.completedAt)}</td>
                    <td className="py-2 px-3 text-sm">
                      {quiz.score}/{quiz.totalQuestions}
                    </td>
                    <td className="py-2 px-3 text-sm">
                      <span className={`font-medium ${
                        quiz.accuracy >= 0.8 ? 'text-green-600' :
                        quiz.accuracy >= 0.6 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {(quiz.accuracy * 100).toFixed(1)}%
                      </span>
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-600">
                      {formatDuration(quiz.timeSpentSeconds)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {user.dailyQuizzes.length > 10 && (
              <div className="text-sm text-gray-500 mt-2 text-center">
                Showing 10 of {user.dailyQuizzes.length} quizzes
              </div>
            )}
          </div>
        ) : (
          <div className="text-gray-500 text-center py-4">No daily quizzes completed yet</div>
        )}
      </div>

      {/* Chapter Practice */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">
          Chapter Practice ({user.chapterPractice?.length || 0})
        </h2>
        {user.chapterPractice && user.chapterPractice.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Chapter</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Subject</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Score</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Accuracy</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Time</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {user.chapterPractice.slice(0, 10).map((session, idx) => (
                  <tr key={session.id || idx} className="hover:bg-gray-50">
                    <td className="py-2 px-3 text-sm">{session.chapterName}</td>
                    <td className="py-2 px-3 text-sm capitalize">{session.subject}</td>
                    <td className="py-2 px-3 text-sm">
                      {session.score}/{session.totalQuestions}
                    </td>
                    <td className="py-2 px-3 text-sm">
                      <span className={`font-medium ${
                        session.accuracy >= 0.8 ? 'text-green-600' :
                        session.accuracy >= 0.6 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {(session.accuracy * 100).toFixed(1)}%
                      </span>
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-600">
                      {formatDuration(session.timeSpentSeconds)}
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-600">
                      {formatDate(session.completedAt)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {user.chapterPractice.length > 10 && (
              <div className="text-sm text-gray-500 mt-2 text-center">
                Showing 10 of {user.chapterPractice.length} sessions
              </div>
            )}
          </div>
        ) : (
          <div className="text-gray-500 text-center py-4">No chapter practice sessions yet</div>
        )}
      </div>

      {/* Mock Tests */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">
          Mock Tests ({user.mockTests?.length || 0})
        </h2>
        {user.mockTests && user.mockTests.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Test Name</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Score</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Accuracy</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Time</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {user.mockTests.map((test, idx) => (
                  <tr key={test.id || idx} className="hover:bg-gray-50">
                    <td className="py-2 px-3 text-sm">{test.testName}</td>
                    <td className="py-2 px-3 text-sm">
                      {test.score}/{test.maxScore}
                    </td>
                    <td className="py-2 px-3 text-sm">
                      <span className={`font-medium ${
                        test.accuracy >= 0.8 ? 'text-green-600' :
                        test.accuracy >= 0.6 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {(test.accuracy * 100).toFixed(1)}%
                      </span>
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-600">
                      {formatDuration(test.timeSpentSeconds)}
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-600">
                      {formatDate(test.completedAt)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-gray-500 text-center py-4">No mock tests completed yet</div>
        )}
      </div>

      {/* Percentile History - Daily Trend */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">
          Percentile Trend
        </h2>
        {user.percentileHistory && user.percentileHistory.length > 0 ? (
          <div className="overflow-x-auto">
            <div className="text-sm text-gray-500 mb-3">
              Last {user.percentileHistory.length} {user.percentileHistory.length === 1 ? 'entry' : 'entries'}
            </div>
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Date & Time</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Percentile</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Theta (θ)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {user.percentileHistory.slice().reverse().slice(0, 30).map((item, idx) => (
                  <tr key={item.date || idx} className="hover:bg-gray-50">
                    <td className="py-2 px-3 text-sm text-gray-600">{formatDateTime(item.date)}</td>
                    <td className="py-2 px-3 text-sm">
                      <span className={`font-medium ${
                        item.percentile >= 80 ? 'text-green-600' :
                        item.percentile >= 60 ? 'text-blue-600' :
                        item.percentile >= 40 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {item.percentile}%
                      </span>
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-800">{item.theta || 'N/A'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {user.percentileHistory.length > 30 && (
              <div className="text-sm text-gray-500 mt-2 text-center">
                Showing most recent 30 of {user.percentileHistory.length} entries
              </div>
            )}
          </div>
        ) : (
          <div className="text-gray-500 text-center py-4">
            No percentile history yet. Snapshots are created after completing daily quizzes.
          </div>
        )}
      </div>

      {/* Accuracy History - Daily Trend */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">
          Accuracy Trend
        </h2>
        {user.accuracyHistory && user.accuracyHistory.length > 0 ? (
          <div className="overflow-x-auto">
            <div className="text-sm text-gray-500 mb-3">
              Last {user.accuracyHistory.length} {user.accuracyHistory.length === 1 ? 'entry' : 'entries'} • Current: {user.progress.overallAccuracy || 0}%
            </div>
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Date & Time</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Accuracy</th>
                  <th className="text-left py-2 px-3 text-sm font-medium text-gray-500">Questions (Correct/Total)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {user.accuracyHistory.slice().reverse().slice(0, 30).map((item, idx) => (
                  <tr key={item.date || idx} className="hover:bg-gray-50">
                    <td className="py-2 px-3 text-sm text-gray-600">{formatDateTime(item.date)}</td>
                    <td className="py-2 px-3 text-sm">
                      <span className={`font-medium ${
                        item.accuracy >= 85 ? 'text-green-600' :
                        item.accuracy >= 70 ? 'text-blue-600' :
                        item.accuracy >= 50 ? 'text-yellow-600' :
                        'text-red-600'
                      }`}>
                        {item.accuracy}%
                      </span>
                    </td>
                    <td className="py-2 px-3 text-sm text-gray-600">
                      {item.correct || 0}/{item.total || 0}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {user.accuracyHistory.length > 30 && (
              <div className="text-sm text-gray-500 mt-2 text-center">
                Showing most recent 30 of {user.accuracyHistory.length} entries
              </div>
            )}
          </div>
        ) : (
          <div className="text-gray-500 text-center py-4">
            No accuracy history yet. Data will appear after completing daily quizzes with the new system.
          </div>
        )}
      </div>
    </div>
  );
}
