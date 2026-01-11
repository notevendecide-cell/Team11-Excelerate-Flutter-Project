# SkillTrack Pro — Internship & Learning Management Platform

SkillTrack Pro is a learning + internship tracking system with a Flutter mobile app and a Node.js/Express + PostgreSQL backend.

Core flow:

- Admin creates a Program with Modules (learning path) and module Deliverables.
- Learners work module-by-module, submit deliverables, and track completion progress.
- Mentors review/approve submissions.
- After 100% completion, learners can submit a program-level review; mentors/admins can view review summaries.

## Repository structure

- `backend/` — REST API (Express + Postgres)
- `frontend/` — Flutter app (learner/mentor/admin roles)

## Documentation

- User manual: [docs/USER_MANUAL.md](docs/USER_MANUAL.md)
- Developer guide: [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)


## Quickstart (local development)

### 1) Backend

```bash
cd backend
cp .env.example .env
npm install
npm run migrate
npm run seed
npm run dev
```

API runs on `http://localhost:3000` by default.

Full backend docs: [backend/README.md](backend/README.md)

### 2) Frontend

```bash
cd frontend
flutter pub get
flutter run
```

To point the app at a different backend URL:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Full frontend docs: [frontend/README.md](frontend/README.md)

## Roles

The app supports:

- Learner
- Mentor
- Admin

Authentication is token-based (JWT). RBAC and permission checks are enforced by the backend.

## Branch Management Guide

This guide will help you understand how to work with different branches in this repository.

### Understanding Branches

This project uses multiple branches for different purposes:

- **`main`** - Production-ready code. Only merge here after thorough testing.
- **`develop`** - Development branch where features come together. This is the integration branch.
- **`feature/*`** - Feature branches for developing new features (e.g., `feature/user-authentication`).
- **`bugfix/*`** - Branches for fixing bugs (e.g., `bugfix/login-issue`).
- **`hotfix/*`** - Critical fixes for production issues.

### How to Checkout a Branch

#### 1. View All Available Branches

```bash
# View local branches
git branch

# View remote branches
git branch -r

# View all branches (local and remote)
git branch -a
```

#### 2. Checkout a Local Branch

If the branch already exists locally:

```bash
git checkout branch-name
```

Or using the newer syntax:

```bash
git switch branch-name
```

**Example:**
```bash
git checkout develop
git checkout feature/user-authentication
```

#### 3. Checkout a Remote Branch (First Time)

If you want to work on a remote branch that doesn't exist locally yet:

```bash
git checkout -b branch-name origin/branch-name
```

Or simply:

```bash
git checkout branch-name
```

Git will automatically create a local tracking branch if it finds a matching remote branch.

**Example:**
```bash
git checkout -b develop origin/develop
git checkout feature/dashboard
```

#### 4. Update Your Local Branch

Before starting work, always pull the latest changes from remote:

```bash
git pull origin branch-name
```

Or if you're already on the branch:

```bash
git pull
```

### Common Workflow

1. **Start working on a feature:**
   ```bash
   # Fetch latest changes
   git fetch origin
   
   # Create or checkout feature branch
   git checkout -b feature/my-feature origin/develop
   
   # Or if branch already exists
   git checkout feature/my-feature
   git pull
   ```

2. **Make your changes:**
   ```bash
   # Stage and commit changes
   git add .
   git commit -m "Add new feature description"
   ```

3. **Push your work:**
   ```bash
   git push origin feature/my-feature
   ```

4. **Create a Pull Request:**
   - Go to GitHub repository
   - Click "New Pull Request"
   - Select your feature branch and target branch (usually `develop`)

5. **Switch back to develop:**
   ```bash
   git checkout develop
   git pull
   ```

### Useful Git Commands

#### Check Current Branch

```bash
git status
```

#### Create a New Branch

```bash
# Create and checkout a new branch
git checkout -b feature/my-feature

# Or create without checking out
git branch feature/my-feature
```

#### Delete a Branch

```bash
# Delete local branch
git branch -d branch-name

# Force delete local branch (if not merged)
git branch -D branch-name

# Delete remote branch
git push origin --delete branch-name
```

#### Rename a Branch

```bash
# Rename current branch
git branch -m new-branch-name

# Rename specific branch
git branch -m old-name new-name
```

#### Sync Your Branch with Main Branch

```bash
# Make sure you're on your feature branch
git checkout feature/my-feature

# Rebase with develop
git pull --rebase origin develop

# Or merge (creates a merge commit)
git pull origin develop
```

### Troubleshooting

#### "Branch not found" Error

```bash
# Fetch latest from remote
git fetch origin

# Then try checking out again
git checkout branch-name
```

#### Unstaged Changes Blocking Checkout

```bash
# Stash your changes (save them temporarily)
git stash

# Checkout to another branch
git checkout branch-name

# Return to previous branch and restore changes
git checkout previous-branch
git stash pop
```

#### Wrong Branch? Undo Changes

```bash
# Go back to previous branch
git checkout -

# Or go to specific branch
git checkout branch-name
```

### Best Practices

✅ **DO:**
- Always pull before starting work (`git pull`)
- Use meaningful branch names (`feature/user-login`, not `fix123`)
- Keep branches focused on single features
- Regularly sync your branch with `develop`
- Delete merged branches to keep repository clean

❌ **DON'T:**
- Directly commit to `main` or `develop` (use feature branches)
- Leave stale branches undeleted
- Force push to shared branches
- Commit sensitive information (API keys, passwords)

### Getting Help

If you're stuck:

```bash
# Show git log to understand commit history
git log --oneline -n 10

# Show difference between branches
git diff branch1 branch2

# Show what changes are in your branch
git diff origin/develop
```

---

**Need more help?** Ask your team lead or refer to the [Git Documentation](https://git-scm.com/doc).