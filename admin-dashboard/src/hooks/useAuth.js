import { useState, useEffect } from 'react';
import { onAuthStateChanged, signInWithPopup, signOut } from 'firebase/auth';
import { auth, googleProvider } from '../services/firebase';
import { isAllowedAdmin } from '../config/auth';

export function useAuth() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        const adminStatus = isAllowedAdmin(user.email);
        setUser(user);
        setIsAdmin(adminStatus);
        if (!adminStatus) {
          setError('Access denied. You are not authorized as an admin.');
        } else {
          setError(null);
        }
      } else {
        setUser(null);
        setIsAdmin(false);
        setError(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const signInWithGoogle = async () => {
    try {
      setError(null);
      const result = await signInWithPopup(auth, googleProvider);
      const user = result.user;

      if (!isAllowedAdmin(user.email)) {
        await signOut(auth);
        throw new Error('Access denied. You are not authorized as an admin.');
      }

      return user;
    } catch (err) {
      setError(err.message);
      throw err;
    }
  };

  const logout = async () => {
    try {
      await signOut(auth);
    } catch (err) {
      setError(err.message);
      throw err;
    }
  };

  return {
    user,
    loading,
    error,
    isAdmin,
    signInWithGoogle,
    logout
  };
}

export default useAuth;
