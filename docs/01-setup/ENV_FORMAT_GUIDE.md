# .env File Format Guide for Firebase

## Issue with Current Format

The current `.env` file has quotes around `FIREBASE_PRIVATE_KEY`, which can cause parsing issues. Here are the correct formats:

## Option 1: Without Quotes (Recommended)

```env
# Firebase Configuration
FIREBASE_PROJECT_ID=jeevibe
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDMTNHL0qObl+QO\nxWpu54UbcyKrCYekadKUwNWBpBgzq6eRjw/+DJyRA6/vgwAPt2vj77uaNzdNIdVv\n2LRjhQF9FpGOcADjNuB6PtsdpM0x7FhuEpjOZQ6acOj3XLEv/3S8s6fy+TMpFYsF\noZz1BWH54j4M9+fH3a7BMFFi44dfKRkTdb+5HwKZPL8SdAm+1i7epeQEnWkgwL6i\nYE3j8xUcMCwn6/JarVGXwEhTWD8GJUGwCpY81J2SrV1zE32DDwVoWzv3xLYceYtg\nHslT3Mzo/K0H2uMV5E5Xto7OXMnEO12j8pbk6d4tP9FkvaROHIj5/q77LHlVAi2K\nqWJ57YxPAgMBAAECggEAHxHhvW8uiDesgciT3AOkEnLLR3AJa7+CPIgqZZm96oHF\nAqswrJtgu4xwLGs4+QA/+BLEmPqjvjxn2CeAoOVLPtRN/6JYqDV3ecU8ZUDjyfSz\n1XhI5T6o3rj5h8EA221XZL6ny0O10Z41SH51vyz547BSF9PN2+9X/TPAH4YTLNfu\nyuiJwqcZILhwGgInBPgOG/+FIU6b7dg/GGX9J/BhuAsy9wuXFu+HkA2pPk76FCLl\nL7LD63c0UqY7eyhrTg1aNPpHCG/qzxlBuxoSQc9Z53qIIGoUhumfNH894sI9LgN0\nHdCkQp3sADEkGx86E46IxVjAmDQz6Nh4+f+XDhLQ8QKBgQDsAy+xchIxUPuIZcYp\nTqJTDuZeLAKNpa5sUiOL7HYHZKQbZsL4gxTZL6KUiuCvDu7pcz24cTIpcImcdA0h\nPHytK9umsD58tLqjqeDmfskk3j3Xi4XsYkKL4XIj1NtJwLn+8RcKP/YAEZiqvLp3\nihLur1AaDnIIJFarO0ZKIckssQKBgQDdmhm26tS+arbJrklcfYgBbi37pJCaVwso\nKzs7d9YfGWWfgJPYIkxDLjqMNQ7w4JR8RpQ5Jb91KQWZtHezmyYhbspV1wu+DCV4\ncE9yDT0ryAnSy107RdQBYQtJ2FJZEG4dk1XTejqrizaBVvRJAx8sk4L/8FwA2+Ym\nCoTkIoyI/wKBgQCGSgHXK5riaLvWjmJEmrOOIwo9Rzlks4Mdq1cChNdbuY4O8Ve6\n44r3UT1m2+agdRTHzISv7+ik353NYdMeuDYQqsXegKXte0A/Y6fOPxHgYnw5qu/W\n4soOoYa6kKD9xCWQxElh0ab9vwVpEN3gqrW/Dg275cBIlbSi1aVXBQZc4QKBgBPN\nET8m/JuHLY4X5LY/AUgfcDxsF/+yh2yvcDuAGcHtowb9ljhZ2DaoitK8avlbF+mC\n5Pu2Q8VURQvW9Fs4IdAa9jl1Xbc9npuEbZTjWfPvi/Ep+sqxEqCM61VN3w3WSgCa\nibC720I4zkYAXxOnE8IH7EyyTYZGH+qGRhmcfLJBAoGAR7WYdVUWmo5LccH5SufJ\nJfdsphMdFpLJ/oqZ6HXECPhJBo6n1Xv8DezU+Z6ZGkLbjSe3odU/4Hfoe/IBrozo\n072WNWSYCt1oZcPLUjHTATtADZv7rMD8N+JOUwVXkzZXJo8DdMTL8J2ebL5nr0OF\nyElCpXKSZHDQn06RY+u7wrw=\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@jeevibe.iam.gserviceaccount.com
```

**Key Points:**
- No quotes around the private key
- Keep it on a single line
- Use `\n` escape sequences for newlines
- The code will automatically convert `\n` to actual newlines

## Option 2: With Single Quotes (Alternative)

Some deployment platforms require quotes. If so, use single quotes:

```env
FIREBASE_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDMTNHL0qObl+QO\n...\n-----END PRIVATE KEY-----\n'
```

The code will automatically remove single or double quotes.

## Option 3: Multi-line Format (Not Recommended)

Some systems support multi-line values, but it's not standard:

```env
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDMTNHL0qObl+QO
...
-----END PRIVATE KEY-----"
```

**This format is NOT recommended** as it's not portable across all systems.

## For Production Deployment

### Vercel (Your Current Platform) ⭐

**Important**: Vercel uses serverless functions, so you **cannot** use service account files. You **must** use environment variables.

#### Setting Environment Variables in Vercel

**Option A: Via Vercel Dashboard (Recommended)**

1. Go to your project on [Vercel Dashboard](https://vercel.com/dashboard)
2. Click on your project
3. Go to **Settings** → **Environment Variables**
4. Add each variable:

   ```
   Name: FIREBASE_PROJECT_ID
   Value: jeevibe
   ```

   ```
   Name: FIREBASE_PRIVATE_KEY
   Value: -----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDMTNHL0qObl+QO\nxWpu54UbcyKrCYekadKUwNWBpBgzq6eRjw/+DJyRA6/vgwAPt2vj77uaNzdNIdVv\n2LRjhQF9FpGOcADjNuB6PtsdpM0x7FhuEpjOZQ6acOj3XLEv/3S8s6fy+TMpFYsF\noZz1BWH54j4M9+fH3a7BMFFi44dfKRkTdb+5HwKZPL8SdAm+1i7epeQEnWkgwL6i\nYE3j8xUcMCwn6/JarVGXwEhTWD8GJUGwCpY81J2SrV1zE32DDwVoWzv3xLYceYtg\nHslT3Mzo/K0H2uMV5E5Xto7OXMnEO12j8pbk6d4tP9FkvaROHIj5/q77LHlVAi2K\nqWJ57YxPAgMBAAECggEAHxHhvW8uiDesgciT3AOkEnLLR3AJa7+CPIgqZZm96oHF\nAqswrJtgu4xwLGs4+QA/+BLEmPqjvjxn2CeAoOVLPtRN/6JYqDV3ecU8ZUDjyfSz\n1XhI5T6o3rj5h8EA221XZL6ny0O10Z41SH51vyz547BSF9PN2+9X/TPAH4YTLNfu\nyuiJwqcZILhwGgInBPgOG/+FIU6b7dg/GGX9J/BhuAsy9wuXFu+HkA2pPk76FCLl\nL7LD63c0UqY7eyhrTg1aNPpHCG/qzxlBuxoSQc9Z53qIIGoUhumfNH894sI9LgN0\nHdCkQp3sADEkGx86E46IxVjAmDQz6Nh4+f+XDhLQ8QKBgQDsAy+xchIxUPuIZcYp\nTqJTDuZeLAKNpa5sUiOL7HYHZKQbZsL4gxTZL6KUiuCvDu7pcz24cTIpcImcdA0h\nPHytK9umsD58tLqjqeDmfskk3j3Xi4XsYkKL4XIj1NtJwLn+8RcKP/YAEZiqvLp3\nihLur1AaDnIIJFarO0ZKIckssQKBgQDdmhm26tS+arbJrklcfYgBbi37pJCaVwso\nKzs7d9YfGWWfgJPYIkxDLjqMNQ7w4JR8RpQ5Jb91KQWZtHezmyYhbspV1wu+DCV4\ncE9yDT0ryAnSy107RdQBYQtJ2FJZEG4dk1XTejqrizaBVvRJAx8sk4L/8FwA2+Ym\nCoTkIoyI/wKBgQCGSgHXK5riaLvWjmJEmrOOIwo9Rzlks4Mdq1cChNdbuY4O8Ve6\n44r3UT1m2+agdRTHzISv7+ik353NYdMeuDYQqsXegKXte0A/Y6fOPxHgYnw5qu/W\n4soOoYa6kKD9xCWQxElh0ab9vwVpEN3gqrW/Dg275cBIlbSi1aVXBQZc4QKBgBPN\nET8m/JuHLY4X5LY/AUgfcDxsF/+yh2yvcDuAGcHtowb9ljhZ2DaoitK8avlbF+mC\n5Pu2Q8VURQvW9Fs4IdAa9jl1Xbc9npuEbZTjWfPvi/Ep+sqxEqCM61VN3w3WSgCa\nibC720I4zkYAXxOnE8IH7EyyTYZGH+qGRhmcfLJBAoGAR7WYdVUWmo5LccH5SufJ\nJfdsphMdFpLJ/oqZ6HXECPhJBo6n1Xv8DezU+Z6ZGkLbjSe3odU/4Hfoe/IBrozo\n072WNWSYCt1oZcPLUjHTATtADZv7rMD8N+JOUwVXkzZXJo8DdMTL8J2ebL5nr0OF\nyElCpXKSZHDQn06RY+u7wrw=\n-----END PRIVATE KEY-----\n
   ```
   **Important**: 
   - Paste the entire private key on **one line**
   - Keep the `\n` escape sequences (don't convert to actual newlines)
   - No quotes needed

   ```
   Name: FIREBASE_CLIENT_EMAIL
   Value: firebase-adminsdk-fbsvc@jeevibe.iam.gserviceaccount.com
   ```

5. Select **Environment**: Production, Preview, Development (or just Production)
6. Click **Save**
7. **Redeploy** your project for changes to take effect

**Option B: Via Vercel CLI**

```bash
# Install Vercel CLI if not already installed
npm i -g vercel

# Set environment variables
vercel env add FIREBASE_PROJECT_ID
# Enter: jeevibe

vercel env add FIREBASE_PRIVATE_KEY
# Paste the entire private key (one line with \n)

vercel env add FIREBASE_CLIENT_EMAIL
# Enter: firebase-adminsdk-fbsvc@jeevibe.iam.gserviceaccount.com

# Pull env vars to local .env (optional)
vercel env pull .env.local
```

#### Vercel-Specific Notes

1. **No Service Account Files**: Vercel serverless functions don't have file system access, so you **must** use environment variables
2. **Environment Scope**: Set variables for Production, Preview, and Development as needed
3. **Redeploy Required**: After adding/updating env vars, redeploy your project
4. **Private Key Format**: 
   - Paste as single line with `\n` escape sequences
   - Vercel dashboard handles multi-line values, but single line is safer
5. **Character Limits**: Vercel has a limit on env var size, but private keys should be fine

#### Testing on Vercel

After setting environment variables and redeploying:

1. Check Vercel function logs for:
   ```
   ✅ Firebase Admin initialized with environment variables
   ```

2. Test your endpoint:
   ```bash
   curl https://your-project.vercel.app/api/test/firestore
   ```

#### Troubleshooting on Vercel

**Error: "Firebase configuration not found"**
- Verify all 3 env vars are set in Vercel dashboard
- Check that you selected the correct environment (Production/Preview/Development)
- Redeploy after adding env vars

**Error: "Invalid private key format"**
- Ensure private key is on one line
- Keep `\n` escape sequences (don't convert to actual newlines)
- No quotes around the value

**Error: "Getting metadata from plugin failed"**
- Usually means private key parsing failed
- Double-check the private key value in Vercel dashboard
- Try removing and re-adding the variable

### Heroku
Use Heroku config vars (no quotes needed):
```bash
heroku config:set FIREBASE_PROJECT_ID=jeevibe
heroku config:set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
heroku config:set FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@jeevibe.iam.gserviceaccount.com
```

### AWS (ECS/EC2)
Use AWS Secrets Manager or Parameter Store:
- Store as JSON
- Retrieve and parse in code
- Or use environment variables (same format as Option 1)

### Docker
In `docker-compose.yml`:
```yaml
environment:
  - FIREBASE_PROJECT_ID=jeevibe
  - FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...
  - FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@jeevibe.iam.gserviceaccount.com
```

Or use `.env` file (Option 1 format).

## Testing

After updating your `.env` file:

1. **Remove the service account file** (to force env var usage):
   ```bash
   mv serviceAccountKey.json serviceAccountKey.json.backup
   ```

2. **Restart your server**:
   ```bash
   npm start
   ```

3. **Test the connection**:
   ```bash
   curl http://localhost:3000/api/test/firestore
   ```

4. **Check server logs** for:
   ```
   ✅ Firebase Admin initialized with environment variables
   ```

## Current Code Behavior

The updated `firebase.js` will:
1. ✅ Try service account file first (if exists)
2. ✅ Fall back to environment variables
3. ✅ Automatically remove quotes (single or double)
4. ✅ Convert `\n` to actual newlines
5. ✅ Validate private key format
6. ✅ Provide clear error messages

## Troubleshooting

### Error: "Invalid private key format"
- Check that `BEGIN PRIVATE KEY` is in the value
- Ensure `\n` escape sequences are present (not actual newlines)

### Error: "FIREBASE_CLIENT_EMAIL is required"
- Add `FIREBASE_CLIENT_EMAIL` to your `.env` file

### Still not working?
- Check server logs for detailed error messages
- Verify all three variables are set: `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`
- Try removing quotes entirely (Option 1)
