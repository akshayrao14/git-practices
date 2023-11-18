Branching

We use different "levels" of branches based on stability or extent of collaboration with the team.

Feature Branch
==============

If you're working on fixing a bug or developing a new feature on existing code, then you should create a "feature branch" for it. The feature branch will be all yours to handle and manage.

How to do it:

-   Go to your local repository

-   git status - see which branch you're on right now. This will become your "base branch" from where you branch out.

-   Ideally, you should branch out should be whatever your team is collaborating on. Check with the team which your base branch should be.

-   If your base branch's name is team-base-branch, then first switch to that branch.

Switching to your team's base branch

-   git fetch --all // This will tell your local git about whatever new branches exist on the remote repository

-   git checkout team-base-branch // changes your branch to your base branch

-   git status // see if there are any local changes. If there are. Remove them if you think you'll get some conflicts in the next step.

Branching out

-   git pull origin team-base-branch // This will pull the latest changes into your local branch

-   There may be some conflicts. You must resolve them. Check with your team on how to.

-   If all goes well, your local base branch is ready to be used to create your feature branch.

-   git checkout -b my-feature-branch-name

-   You're good to go!

Integration Branch

Staging Branch

Pre-Release Branch

Release Branch

Before you push your code
=========================

How to merge your code with your team's codeBranching

We use different "levels" of branches based on stability or extent of collaboration with the team.

Feature Branch
==============

If you're working on fixing a bug or developing a new feature on existing code, then you should create a "feature branch" for it. The feature branch will be all yours to handle and manage.

How to do it:

-   Go to your local repository

-   git status - see which branch you're on right now. This will become your "base branch" from where you branch out.

-   Ideally, you should branch out should be whatever your team is collaborating on. Check with the team which your base branch should be.

-   If your base branch's name is team-base-branch, then first switch to that branch.

Switching to your team's base branch

-   git fetch --all // This will tell your local git about whatever new branches exist on the remote repository

-   git checkout team-base-branch // changes your branch to your base branch

-   git status // see if there are any local changes. If there are. Remove them if you think you'll get some conflicts in the next step.

Branching out

-   git pull origin team-base-branch // This will pull the latest changes into your local branch

-   There may be some conflicts. You must resolve them. Check with your team on how to.

-   If all goes well, your local base branch is ready to be used to create your feature branch.

-   git checkout -b my-feature-branch-name

-   You're good to go!

Integration Branch

Staging Branch

Pre-Release Branch

Release Branch

Before you push your code
=========================

How to merge your code with your team's code

git pull --rebase origin integ-branch

Resolve conflicts

Raise PR

Squash commits