import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { formatDistanceToNow } from 'date-fns';
import api from '../services/api';
import AssignStudentsModal from '../components/teachers/AssignStudentsModal';

export default function TeacherDetail() {
  const { teacherId } = useParams();
  const [teacher, setTeacher] = useState(null);
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [studentFilter, setStudentFilter] = useState('all');
  const [showAssignModal, setShowAssignModal] = useState(false);

  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true);
        const [teacherResult, studentsResult] = await Promise.all([
          api.getTeacher(teacherId),
          api.getTeacherStudents(teacherId, { filter: studentFilter, limit: 100 })
        ]);
        setTeacher(teacherResult.data);
        setStudents(studentsResult.data.students);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [teacherId, studentFilter]);

  const refreshData = async () => {
    try {
      setLoading(true);
      const [teacherResult, studentsResult] = await Promise.all([
        api.getTeacher(teacherId),
        api.getTeacherStudents(teacherId, { filter: studentFilter, limit: 100 })
      ]);
      setTeacher(teacherResult.data);
      setStudents(studentsResult.data.students);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveStudent = async (studentId) => {
    if (!confirm('Are you sure you want to remove this student from the teacher?')) {
      return;
    }
    try {
      await api.removeStudentFromTeacher(teacherId, studentId);
      await refreshData();
    } catch (err) {
      setError(err.message);
    }
  };

  const formatDate = (date) => {
    if (!date) return 'Never';
    try {
      return formatDistanceToNow(new Date(date), { addSuffix: true });
    } catch {
      return 'Unknown';
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="text-center py-12">
          Loading teacher details...
        </div>
      </div>
    );
  }

  if (error || !teacher) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
          {error || 'Teacher not found'}
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Breadcrumb */}
      <nav className="mb-6">
        <Link to="/teachers" className="text-primary-600 hover:text-primary-800">
          ← Back to Teachers
        </Link>
      </nav>

      {/* Teacher Profile Card */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
        <div className="flex justify-between items-start">
          <div>
            <h1 className="text-2xl font-bold text-gray-800 mb-2">
              {teacher.first_name} {teacher.last_name}
            </h1>
            <div className="space-y-1 text-sm text-gray-600">
              <div>📧 {teacher.email}</div>
              <div>📱 {teacher.phone_number}</div>
              {teacher.coaching_institute_name && (
                <div>🏫 {teacher.coaching_institute_name}</div>
              )}
              {teacher.coaching_institute_location && (
                <div>📍 {teacher.coaching_institute_location}</div>
              )}
            </div>
          </div>
          <div className="text-right">
            <div className="text-sm text-gray-500 mb-2">Total Students</div>
            <div className="text-3xl font-bold text-primary-600">{teacher.total_students || 0}</div>
          </div>
        </div>

        <div className="mt-6 pt-6 border-t border-gray-200 flex gap-4">
          <div className="flex-1">
            <div className="text-xs text-gray-500 mb-1">Status</div>
            <span className={`px-3 py-1 rounded-full text-xs font-medium ${
              teacher.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'
            }`}>
              {teacher.is_active ? 'Active' : 'Inactive'}
            </span>
          </div>
          <div className="flex-1">
            <div className="text-xs text-gray-500 mb-1">Created</div>
            <div className="text-sm text-gray-900">{formatDate(teacher.created_at)}</div>
          </div>
          <div className="flex-1">
            <div className="text-xs text-gray-500 mb-1">Last Login</div>
            <div className="text-sm text-gray-900">{formatDate(teacher.last_login_at)}</div>
          </div>
        </div>
      </div>

      {/* Assign Students Modal */}
      <AssignStudentsModal
        isOpen={showAssignModal}
        onClose={() => setShowAssignModal(false)}
        teacherId={teacherId}
        onSuccess={refreshData}
      />

      {/* Students Section */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="p-6 border-b border-gray-200 flex justify-between items-center">
          <h2 className="text-lg font-semibold text-gray-800">Students</h2>
          <div className="flex gap-3 items-center">
            <button
              onClick={() => setShowAssignModal(true)}
              className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors text-sm"
            >
              + Assign Students
            </button>
            <select
              value={studentFilter}
              onChange={(e) => setStudentFilter(e.target.value)}
              className="px-3 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 bg-white"
            >
              <option value="all">All Students</option>
              <option value="active">Active (last 7 days)</option>
              <option value="inactive">Inactive (7+ days)</option>
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-200">
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Phone
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Class
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Percentile
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Questions
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Last Active
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {students.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-12 text-center text-gray-500">
                    No students associated with this teacher
                  </td>
                </tr>
              ) : (
                students.map((student) => (
                  <tr key={student.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <div className="text-sm font-medium text-gray-900">
                        {student.firstName || student.first_name || 'N/A'} {student.lastName || student.last_name || ''}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {student.phoneNumber || student.phone_number || '-'}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {student.currentClass || 'N/A'}
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        (student.overall_percentile || 0) >= 70 ? 'bg-green-100 text-green-700' :
                        (student.overall_percentile || 0) >= 40 ? 'bg-yellow-100 text-yellow-700' :
                        'bg-red-100 text-red-700'
                      }`}>
                        {Math.round(student.overall_percentile || 0)}%
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-900">
                      {student.total_questions_solved || 0}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {formatDate(student.lastActive)}
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <button
                        onClick={() => handleRemoveStudent(student.id)}
                        className="text-red-600 hover:text-red-900"
                      >
                        Remove
                      </button>
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
