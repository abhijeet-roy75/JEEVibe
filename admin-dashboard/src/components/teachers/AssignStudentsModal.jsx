import { useState, useEffect } from 'react';
import api from '../../services/api';

export default function AssignStudentsModal({ isOpen, onClose, teacherId, onSuccess }) {
  const [students, setStudents] = useState([]);
  const [selectedStudents, setSelectedStudents] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (isOpen) {
      fetchAvailableStudents();
    }
  }, [isOpen, search]);

  const fetchAvailableStudents = async () => {
    try {
      setLoading(true);
      setError(null);
      // Fetch users who are enrolled in coaching but not assigned to any teacher
      const result = await api.getUsers({
        search,
        limit: 50,
        isEnrolledInCoaching: true,
        hasNoTeacher: true
      });
      setStudents(result.data.users || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleStudent = (studentId) => {
    setSelectedStudents(prev =>
      prev.includes(studentId)
        ? prev.filter(id => id !== studentId)
        : [...prev, studentId]
    );
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (selectedStudents.length === 0) {
      setError('Please select at least one student');
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      await api.addStudentsToTeacher(teacherId, selectedStudents);
      onSuccess();
      onClose();
      setSelectedStudents([]);
      setSearch('');
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full mx-4 max-h-[80vh] flex flex-col">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-800">Assign Students to Teacher</h2>
          <p className="text-sm text-gray-500 mt-1">
            Select students who are enrolled in coaching but not assigned to any teacher
          </p>
        </div>

        <form onSubmit={handleSubmit} className="flex-1 flex flex-col overflow-hidden">
          <div className="p-6 space-y-4 flex-1 overflow-auto">
            {error && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-red-700 text-sm">
                {error}
              </div>
            )}

            <div>
              <input
                type="text"
                placeholder="Search by name or phone..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              />
            </div>

            {loading ? (
              <div className="text-center py-8 text-gray-500">
                Loading students...
              </div>
            ) : students.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                No available students found. Students must be enrolled in coaching and not assigned to any teacher.
              </div>
            ) : (
              <div className="space-y-2">
                <div className="text-sm text-gray-600 mb-2">
                  {selectedStudents.length} student(s) selected
                </div>
                {students.map((student) => (
                  <label
                    key={student.id}
                    className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer"
                  >
                    <input
                      type="checkbox"
                      checked={selectedStudents.includes(student.id)}
                      onChange={() => handleToggleStudent(student.id)}
                      className="w-4 h-4 text-primary-600 rounded focus:ring-2 focus:ring-primary-500"
                    />
                    <div className="flex-1">
                      <div className="text-sm font-medium text-gray-900">
                        {student.firstName} {student.lastName}
                      </div>
                      <div className="text-xs text-gray-500">
                        {student.phoneNumber} • Class {student.currentClass || 'N/A'}
                      </div>
                    </div>
                    {student.overall_percentile !== undefined && (
                      <div className="text-xs text-gray-600">
                        {Math.round(student.overall_percentile)}% percentile
                      </div>
                    )}
                  </label>
                ))}
              </div>
            )}
          </div>

          <div className="p-6 border-t border-gray-200 flex gap-3">
            <button
              type="button"
              onClick={() => {
                onClose();
                setSelectedStudents([]);
                setSearch('');
              }}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
              disabled={submitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors disabled:opacity-50"
              disabled={submitting || selectedStudents.length === 0}
            >
              {submitting ? 'Assigning...' : `Assign ${selectedStudents.length} Student(s)`}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
