#!/usr/bin/env node

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// Read package.json
const packagePath = path.join(process.cwd(), "package.json");
if (!fs.existsSync(packagePath)) {
  console.error("❌ package.json not found in current directory");
  process.exit(1);
}

const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
const version = pkg.version;

if (!version) {
  console.error("❌ No version found in package.json");
  process.exit(1);
}

const tagName = `v${version}`;

console.log(`📦 Creating draft release for version ${version}...`);

try {
  // Check if gh CLI is installed
  try {
    execSync("gh --version", { stdio: "ignore" });
  } catch (e) {
    console.error("❌ GitHub CLI (gh) is not installed.");
    console.error("   Install it from: https://cli.github.com/");
    process.exit(1);
  }

  // Check if we're in a git repository
  try {
    execSync("git rev-parse --git-dir", { stdio: "ignore" });
  } catch (e) {
    console.error("❌ Not in a git repository");
    process.exit(1);
  }

  // Get the default branch
  const defaultBranch = execSync(
    "gh repo view --json defaultBranchRef --jq .defaultBranchRef.name",
    {
      encoding: "utf8",
    }
  ).trim();

  console.log(`🌿 Default branch: ${defaultBranch}`);
  console.log(`🏷️  Tag name: ${tagName}`);

  // Create draft release
  // Extract title from the --title cli argument. If --title is missing, use the default title
  const defaultTitle = `${tagName}: < DETAILS >`;
  const title = process.argv?.[2] || defaultTitle;

  const result = execSync(
    `gh release create "${tagName}" --draft --title "${title}" --target "${defaultBranch}" --generate-notes`,
    { encoding: "utf8" }
  );

  console.log("✅ Draft release created successfully!");

  // Extract the release URL from the output
  const releaseUrl = result.trim();
  console.log(`🔗 Release URL: ${releaseUrl}`);

  // Open in browser
  console.log("🌐 Opening release page in browser...");
  execSync(`gh release view "${tagName}" --web`, { stdio: "inherit" });
} catch (error) {
  console.error("❌ Error creating release:", error.message);
  process.exit(1);
}
