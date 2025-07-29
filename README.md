This is a working script
Use this script to set up a github repo and CI/CD pipelines for new WPE sites

The root of your WSL install, shall mimic the root of this repo, not including the readme
Feel free to change the structure to how you please, but filepaths in the script will need to be adjusted.
The script is assuming that you have a working ssh config (~/.ssh/config)

You will need WSL:
https://learn.microsoft.com/en-us/windows/wsl/

You will need to generate a GitHub Token:
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

You will need an SSH Key with GitHub:
https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account

You will need an SSH Key with WP Engine:
https://wpengine.com/support/ssh-keys-for-shell-access/

If you move and rename this to /usr/local/bin/wpe-cicd you can use it as a command instead 
mv wpe-cicd.sh /usr/local/bin/wpe-cicd

New site with Production, Staging, and Development:
wpe-cicd --new siteprd sitestg sitedev 'Site Name' www.site.com

Update design site project to have a Production configuration
wpe-cicd --update siteprd sitestg sitedev 'project-name' www.site.com

Design site with just dev environment
wpe-cicd --dev-only sitedev 'Site Name'

Add branch protection rules for prd, stg, dev branches
wpe-cicd --add-rules 'project-name'
