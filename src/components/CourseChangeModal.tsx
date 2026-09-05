import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { golfService } from '../services/golfService';

interface Course {
  id: string;
  name: string;
  description?: string | null;
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
      <div className="bg-card rounded-lg shadow-card max-w-md w-full p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-ink">Cambiar Campo</h2>
          <button
            onClick={onClose}
            className="text-ink-4 hover:text-ink-3 transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <div className="mb-4">
          <p className="text-sm text-ink-3">
            Campo actual: <span className="font-semibold text-ink">{currentCourseName}</span>
          </p>
          <p className="text-xs text-ink-3 mt-1">
            Selecciona el campo correcto para esta ronda
          </p>
        </div>

        {loading ? (
          <div className="py-8 text-center text-ink-3">Cargando campos...</div>
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
                      ? 'border-accent bg-accent-soft cursor-default'
                      : 'border-line hover:border-accent hover:bg-accent-soft'
                  }`}
                >
                  <div className="font-semibold text-ink">{course.name}</div>
                  {course.description && (
                    <div className="text-sm text-ink-3 mt-1">{course.description}</div>
                  )}
                  {isCurrentCourse && (
                    <div className="text-xs text-accent-ink mt-1 font-medium">(Campo actual)</div>
                  )}
                </button>
              );
            })}
          </div>
        )}

        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-neutral hover:bg-neutral-hover text-ink rounded-lg font-semibold transition-colors"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  );
};
