const { generateTrialEmailContent } = require('../../../src/services/studentEmailService');

describe('studentEmailService - Trial Emails', () => {
  describe('generateTrialEmailContent - Name Handling', () => {
    const userId = 'test-user-123';

    describe('firstName field usage', () => {
      test('should use firstName when available', async () => {
        const userData = {
          firstName: 'Abhijeet',
          email: 'test@example.com',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('Abhijeet');
        expect(result.html).toContain('Hi Abhijeet,');
        expect(result.text).toContain('Hi Abhijeet,');
      });

      test('should work with single character firstName', async () => {
        const userData = {
          firstName: 'A',
          email: 'test@example.com',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('A');
        expect(result.html).toContain('Hi A,');
      });

      test('should work with firstName containing spaces', async () => {
        const userData = {
          firstName: 'Abhijeet Roy',
          email: 'test@example.com',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('Abhijeet Roy');
        expect(result.html).toContain('Hi Abhijeet Roy,');
      });
    });

    describe('fallback to email prefix', () => {
      test('should use email prefix when firstName is missing', async () => {
        const userData = {
          email: 'abhijeet@example.com',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('abhijeet');
        expect(result.html).toContain('Hi abhijeet,');
        expect(result.text).toContain('Hi abhijeet,');
      });

      test('should use email prefix when firstName is empty string', async () => {
        const userData = {
          firstName: '',
          email: 'john.doe@example.com',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('john.doe');
        expect(result.html).toContain('Hi john.doe,');
      });

      test('should handle email with + symbol', async () => {
        const userData = {
          email: 'user+test@example.com',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('user+test');
        expect(result.html).toContain('Hi user+test,');
      });
    });

    describe('fallback to "Student"', () => {
      test('should use "Student" when both firstName and email are missing', async () => {
        const userData = {};

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('Student');
        expect(result.html).toContain('Hi Student,');
        expect(result.text).toContain('Hi Student,');
      });

      test('should use "Student" when firstName is null and email is undefined', async () => {
        const userData = {
          firstName: null,
          email: undefined,
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        expect(result.subject).toContain('Student');
        expect(result.html).toContain('Hi Student,');
      });

      test('should use "Student" when email is invalid (no @ symbol)', async () => {
        const userData = {
          email: 'invalidemail',
        };

        const result = await generateTrialEmailContent(userId, userData, 5);

        // Should use whole string as prefix
        expect(result.html).toContain('Hi invalidemail,');
      });
    });
  });

  describe('generateTrialEmailContent - Trial Milestones', () => {
    const userData = {
      firstName: 'Test',
      email: 'test@example.com',
    };

    test('should generate correct subject for 23 days remaining', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 23);

      expect(result.subject).toBe('🎯 Week 1 Complete - Keep Going, Test!');
      expect(result.html).toContain('Week 1 Complete');
      expect(result.html).toContain('23 days left');
      expect(result.text).toContain('23 days left');
    });

    test('should generate correct subject for 5 days remaining', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.subject).toBe('⏰ Only 5 Days Left in Your Pro Trial, Test');
      expect(result.html).toContain('Only 5 Days Left');
      expect(result.html).toContain('5 days');
      expect(result.html).toContain('₹199/month');
      expect(result.text).toContain('5 days');
    });

    test('should generate correct subject for 2 days remaining', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 2);

      expect(result.subject).toBe('⚠️ Trial Ending in 2 Days - Act Now, Test!');
      expect(result.html).toContain('Trial Ending in 2 Days');
      expect(result.html).toContain('2 days');
      expect(result.html).toContain('Last chance');
      expect(result.text).toContain('2 days');
    });

    test('should generate correct subject for trial expiry (0 days)', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 0);

      expect(result.subject).toBe('Your Trial Has Ended - Special Offer Inside, Test 🎁');
      expect(result.html).toContain('Your Trial Has Ended');
      expect(result.html).toContain('TRIAL2PRO');
      expect(result.html).toContain('20% off');
      expect(result.html).toContain('valid for 7 days');
      expect(result.text).toContain('TRIAL2PRO');
    });
  });

  describe('generateTrialEmailContent - Email Structure', () => {
    const userData = {
      firstName: 'Test User',
      email: 'test@example.com',
    };

    test('should include proper HTML structure', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.html).toContain('<!DOCTYPE html>');
      expect(result.html).toContain('<html>');
      expect(result.html).toContain('</html>');
      expect(result.html).toContain('<body>');
      expect(result.html).toContain('</body>');
    });

    test('should include call-to-action button', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.html).toContain('class="cta-button"');
      expect(result.html).toContain('https://app.jeevibe.com');
    });

    test('should include footer with links', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.html).toContain('footer');
      expect(result.html).toContain('https://jeevibe.com');
      expect(result.html).toContain('https://app.jeevibe.com/settings');
    });

    test('should include Team JEEVibe signature', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.html).toContain('Team JEEVibe');
      expect(result.text).toContain('Team JEEVibe');
    });

    test('should have both HTML and plain text versions', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result).toHaveProperty('subject');
      expect(result).toHaveProperty('html');
      expect(result).toHaveProperty('text');

      expect(result.subject).toBeTruthy();
      expect(result.html).toBeTruthy();
      expect(result.text).toBeTruthy();

      expect(result.html.length).toBeGreaterThan(result.text.length);
    });
  });

  describe('generateTrialEmailContent - Special Features', () => {
    const userData = {
      firstName: 'Test',
      email: 'test@example.com',
    };

    test('day 23 email should include tips', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 23);

      expect(result.html).toContain('Tips for Success');
      expect(result.html).toContain('Daily quizzes');
      expect(result.html).toContain('Snap & Solve');
    });

    test('day 5 email should include Pro features list', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.html).toContain('Pro Features');
      expect(result.html).toContain('10 daily Snap & Solve');
      expect(result.html).toContain('Offline mode');
      expect(result.html).toContain('5 mock tests per month');
    });

    test('day 2 email should include urgency message', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 2);

      expect(result.html).toContain('Last chance');
      expect(result.html).toContain('10 daily snaps');
      expect(result.html).toContain('offline access');
    });

    test('day 0 email should include discount code', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 0);

      expect(result.html).toContain('TRIAL2PRO');
      expect(result.html).toContain('20% off');
      expect(result.html).toContain('valid for 7 days');
      expect(result.html).toContain('discount-code');
    });

    test('day 0 email should have special CTA URL with discount code', async () => {
      const result = await generateTrialEmailContent('user-id', userData, 0);

      expect(result.html).toContain('https://app.jeevibe.com/upgrade?code=TRIAL2PRO');
    });
  });

  describe('generateTrialEmailContent - Edge Cases', () => {
    test('should handle undefined milestone (fallback to day 0)', async () => {
      const userData = {
        firstName: 'Test',
        email: 'test@example.com',
      };

      const result = await generateTrialEmailContent('user-id', userData, 999);

      // Should fall back to day 0 template
      expect(result.subject).toContain('Your Trial Has Ended');
    });

    test('should handle special characters in firstName', async () => {
      const userData = {
        firstName: "O'Brien",
        email: 'test@example.com',
      };

      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.subject).toContain("O'Brien");
      expect(result.html).toContain("Hi O'Brien,");
    });

    test('should handle non-Latin characters in firstName', async () => {
      const userData = {
        firstName: 'राज',
        email: 'test@example.com',
      };

      const result = await generateTrialEmailContent('user-id', userData, 5);

      expect(result.subject).toContain('राज');
      expect(result.html).toContain('Hi राज,');
    });
  });
});
