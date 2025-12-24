# GitHub Repository Setup Instructions

Your FairShare project is now ready to be pushed to GitHub! Follow these steps to create the repository and publish your code.

## Step 1: Create a New Repository on GitHub

1. Go to [GitHub](https://github.com) and sign in to your account (username: `z-nossier`)
2. Click the **"+"** icon in the top right corner and select **"New repository"**
3. Fill in the repository details:
   - **Repository name**: `fair-share` (or any name you prefer)
   - **Description**: "A bill splitting app for iOS that scans receipts and calculates fair splits"
   - **Visibility**: Choose **Public** (recommended for open source) or **Private**
   - **DO NOT** initialize with a README, .gitignore, or license (we already have these)
4. Click **"Create repository"**

## Step 2: Add the Remote and Push Your Code

After creating the repository, GitHub will show you setup instructions. Use these commands in your terminal:

```bash
cd /Users/zosman/fair-share

# Add the remote repository (replace with your actual repository URL)
git remote add origin https://github.com/z-nossier/fair-share.git

# Verify the remote was added
git remote -v

# Push your code to GitHub
git branch -M main
git push -u origin main
```

**Note**: If you used a different repository name, replace `fair-share` in the URL with your actual repository name.

## Step 3: Verify on GitHub

1. Go to your repository page on GitHub: `https://github.com/z-nossier/fair-share`
2. You should see all your files, including:
   - README.md
   - LICENSE (MIT License)
   - All Swift source files
   - Xcode project files

## Optional: Update Git Email (if needed)

If you want to use a different email address for commits, you can update it:

```bash
cd /Users/zosman/fair-share
git config user.email "your-email@example.com"
```

Or set it globally for all repositories:

```bash
git config --global user.email "your-email@example.com"
git config --global user.name "z-nossier"
```

## Troubleshooting

### If you get authentication errors:
- Make sure you're logged into GitHub
- You may need to use a Personal Access Token instead of your password
- Or set up SSH keys for authentication

### If the repository already exists:
- If you accidentally initialized the repo with a README, you may need to pull first:
  ```bash
  git pull origin main --allow-unrelated-histories
  git push -u origin main
  ```

## Next Steps

Once your code is on GitHub, you can:
- Add topics/tags to your repository
- Create issues for bugs or feature requests
- Set up GitHub Actions for CI/CD
- Add collaborators
- Create releases when you're ready to publish

