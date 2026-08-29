import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { golfService } from '../services/golfService';

interface Course {
  id: string;
  name: string;
  description: string | null;
}

interface CourseChangeModalProps {
  currentCourseId: string;
  currentCourseName: string;
  onSelectCourse: (course: Course) => void;
  onClose: () => void;
}

export const CourseChangeModal: React.FC<CourseChangeModalProps> = ({
  currentCourseId,
  currentCourseName,
  onSelectCourse,
  onClose,
}) => {
  const [courses, setCourses] = useState<Course[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadCourses = async () => {
      try {
        const allCourses = await golfService.getCourses();
        const sortedCourses = allCourses.sort((a, b) => {
          const aIsCostaAzahar = a.name.includes('Costa Azahar');
          const bIsCostaAzahar = b.name.includes('Costa Azahar');

          if (aIsCostaAzahar && !bIsCostaAzahar) return -1;
          if (!aIsCostaAzahar && bIsCostaAzahar) return 1;
          return 0;
        });
        setCourses(sortedCourses);
      } catch (error) {
        console.error('Error loading courses:', error);
      } finally {
        setLoading(false);
      }
    };

    loadCourses();
  }, []);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-2xl max-w-md w-full p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-gray-900">Cambiar Campo</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <div className="mb-4">
          <p className="text-sm text-gray-600">
            Campo actual: <span className="font-semibold text-gray-900">{currentCourseName}</span>
          </p>
          <p className="text-xs text-gray-500 mt-1">
            Selecciona el campo correcto para esta ronda
          </p>
        </div>

        {loading ? (
          <div className="py-8 text-center text-gray-500">Cargando campos...</div>
        ) : (
          <div className="space-y-2 max-h-96 overflow-y-auto">
            {courses.map((course) => {
              const isCurrentCourse = course.id === currentCourseId;

              return (
                <button
                  key={course.id}
                  onClick={() => !isCurrentCourse && onSelectCourse(course)}
                  disabled={isCurrentCourse}
                  className={`w-full text-left p-4 rounded-lg border-2 transition-all ${
                    isCurrentCourse
                      ? 'border-emerald-500 bg-emerald-50 cursor-default'
                      : 'border-gray-200 hover:border-emerald-400 hover:bg-emerald-50'
                  }`}
                >
                  <div className="font-semibold text-gray-900">{course.name}</div>
                  {course.description && (
                    <div className="text-sm text-gray-600 mt-1">{course.description}</div>
                  )}
                  {isCurrentCourse && (
                    <div className="text-xs text-emerald-600 mt-1 font-medium">(Campo actual)</div>
                  )}
                </button>
              );
            })}
          </div>
        )}

        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-800 rounded-lg font-semibold transition-colors"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  );
};
