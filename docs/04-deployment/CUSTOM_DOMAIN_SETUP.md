# Custom Domain Setup Guide - GoDaddy to Firebase Hosting

This guide explains how to connect your GoDaddy domain (jeevibe.com) to Firebase Hosting.

## Prerequisites

- Domain purchased on GoDaddy: `jeevibe.com`
- Firebase project: `jeevibe`
- Firebase Hosting site: `jeevibe.web.app` (already deployed)

## Step-by-Step Instructions

### Step 1: Add Custom Domain in Firebase Console

1. Go to [Firebase Console - Hosting](https://console.firebase.google.com/project/jeevibe/hosting)
2. Click **"Add custom domain"** button
3. Enter your domain: `jeevibe.com`
4. Click **"Continue"**
5. Firebase will display DNS records you need to add

**Firebase will show you:**
- 2 A records with IP addresses (for root domain)
- 1 CNAME record pointing to `jeevibe.web.app` (for www subdomain)

### Step 2: Configure DNS Records in GoDaddy

1. Log in to [GoDaddy](https://www.godaddy.com)
2. Go to **My Products** → Find **jeevibe.com** → Click **DNS** (or **Manage DNS**)
3. You'll see existing DNS records

#### For Root Domain (jeevibe.com):

**Add/Update A Records:**
- **Type**: A
- **Name**: `@` (or leave blank - represents root domain)
- **Value**: [First IP address from Firebase]
- **TTL**: 1 hour (3600 seconds)

- **Type**: A  
- **Name**: `@` (or leave blank)
- **Value**: [Second IP address from Firebase]
- **TTL**: 1 hour (3600 seconds)

> **Note**: Firebase provides 2 IP addresses for redundancy. Add both as separate A records.

#### For www Subdomain (www.jeevibe.com):

**Add/Update CNAME Record:**
- **Type**: CNAME
- **Name**: `www`
- **Value**: `jeevibe.web.app`
- **TTL**: 1 hour (3600 seconds)

#### Remove/Update Existing Records (if needed):

- If there are existing A records pointing to GoDaddy's landing page, you can either:
  - **Delete them** (recommended)
  - **Update them** to point to Firebase IPs

### Step 3: Verify DNS Configuration

After adding DNS records in GoDaddy:

1. Wait 5-15 minutes for DNS propagation
2. Go back to Firebase Console → Hosting → Custom domains
3. Firebase will automatically verify the DNS records
4. Status will show as **"Connected"** when verified

### Step 4: SSL Certificate Provisioning

- Firebase automatically provisions SSL certificates for custom domains
- This usually takes **15 minutes to 24 hours**
- You'll see SSL status in Firebase Console
- Once active, your site will be accessible at `https://jeevibe.com` and `https://www.jeevibe.com`

## DNS Record Summary

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A | @ | [Firebase IP 1] | Root domain (jeevibe.com) |
| A | @ | [Firebase IP 2] | Root domain (redundancy) |
| CNAME | www | jeevibe.web.app | www subdomain |

## Troubleshooting

### DNS Not Verifying

1. **Check DNS propagation**: Use [whatsmydns.net](https://www.whatsmydns.net) to check if DNS records have propagated globally
2. **Verify records**: Double-check that A records match Firebase's IP addresses exactly
3. **Wait longer**: DNS changes can take up to 48 hours to propagate fully (though usually much faster)

### SSL Certificate Not Provisioning

1. **Wait**: SSL certificates can take up to 24 hours
2. **Check DNS**: Ensure DNS is fully propagated before SSL can be issued
3. **Contact Firebase Support**: If it takes longer than 24 hours

### Site Not Loading After Setup

1. **Clear browser cache**: Try incognito/private browsing mode
2. **Check DNS**: Verify DNS records are correct using `dig jeevibe.com` or `nslookup jeevibe.com`
3. **Check Firebase Console**: Ensure domain shows as "Connected" and SSL is active

## Testing

After setup is complete, test:

- `https://jeevibe.com` - Should load your Firebase-hosted site
- `https://www.jeevibe.com` - Should also load your site
- Both should have valid SSL certificates (green padlock in browser)

## Important Notes

1. **DNS Propagation**: Changes can take 5 minutes to 48 hours, but usually complete within 1 hour
2. **SSL Certificates**: Automatically provisioned by Firebase, no manual setup needed
3. **Both Domains**: Both `jeevibe.com` and `www.jeevibe.com` will work after setup
4. **Firebase Default**: `jeevibe.web.app` will continue to work as well

## After Setup

Once your custom domain is connected:

- All future deployments will automatically update both `jeevibe.web.app` and `jeevibe.com`
- No additional configuration needed
- Firebase handles SSL certificate renewal automatically

## Reference Links

- [Firebase Hosting Custom Domains Documentation](https://firebase.google.com/docs/hosting/custom-domain)
- [GoDaddy DNS Management](https://www.godaddy.com/help/manage-dns-records-680)
