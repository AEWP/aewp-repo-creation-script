#!/bin/bash

# Configuration
# 1. Place the README_TEMPLATE.md, .gitignore_template, buddy_template_prd.yml, buddy_template_stg.yml, buddy_template_dev.yml, and PULL_REQUEST_TEMPLATE.md files in your home directory
# 2. Be sure to install and configure the GH CLI utility
# 3. Update the GH_TOKEN variable to use your personal access token
# 4. Be sure you are able to create new repositories in the AEWP Org account on GitHub before continuing

GH_TOKEN="xXxXxXxXxXxXxXxXxXxXxXxXxXxXx" # Add your GitHub Token here

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --new )
            shift
            new_arg=$1
            install_prd="$1"
            install_stg="$2"
            install_dev="$3"
            project_name="$4"
            domain="$5"
            ;;
        --update )
            shift
            update_arg=$1
            install_prd="$1"
            install_stg="$2"
            install_dev="$3"
            project_name="$4"
            domain="$5"
            ;;
        --dev-only )
            shift
            dev_only_arg=$1
            install_dev="$1"
            project_name="$2"
            ;;
        --add-rules )
            shift
            add_rules_arg=$1
            project_name="$1"
            ;;
    esac
    shift
done

# Function to handle new setup
new_setup() {
    echo "Running new repository setup"
    install_prd="$1"
    install_stg="$2"
    install_dev="$3"
    project_name="$4"
    domain="$5"
    org="AEWP"

    readme_template="$HOME/README_TEMPLATE.md"

    if [ ! -f "$readme_template" ]; then
    echo "Error: README_TEMPLATE.md not found at $readme_template"
    exit 1
    fi

    cd ~/Downloads
    gh repo create $org/${project_name// /-} --private -t americaneagle-com-servers
    gh repo clone $org/${project_name// /-} $install_prd

    target_dir="$HOME/Downloads/$install_prd"
    rsync -arvp "$install_prd@$install_prd.ssh.wpengine.net:~/sites/$install_prd/wp-content/themes/" "$target_dir/themes/" --exclude="kadence/" --exclude="twenty*/" --exclude="astra/" --exclude="g5_helium/" --exclude="genesis/"

    # Add README.md to the project folder
    readme="$target_dir/README.md"
    if [ -f "$readme_template" ]; then
    cp "$readme_template" "$readme"
    sed -i '' -e "s/#Project Name#/$project_name/g" "$readme"
    sed -i '' -e "s/#Install Name#/$install_prd/g" "$readme"
    else
    echo "Error: README_TEMPLATE.md not found at $readme_template"
    exit 1
    fi

    # Add .editorconfig to the project folder
    editorconfig_template="$HOME/.editorconfig_template"
    if [ -f "$editorconfig_template" ]; then
    cp "$editorconfig_template" "$target_dir/.editorconfig"
    git add .editorconfig
    else
    echo "Warning: .editorconfig not found at $editorconfig_template"
    fi

    # Add .gitignore to the project folder
    gitignore_template="$HOME/.gitignore_template"
    cp "$gitignore_template" "$target_dir/.gitignore"

    #Add .vscode to the project folder.
    vscode_template="$HOME/.vscode_template/settings.json"
    if [ -f "$vscode_template" ]; then
    mkdir -p "$target_dir/.vscode"
    cp "$vscode_template" "$target_dir/.vscode/settings.json"
    git add .vscode/settings.json
    else
    echo "Warning: VSCode settings.json not found at $vscode_template"
    fi

    # Add PR Template to the project folder
    pr_template="$HOME/PULL_REQUEST_TEMPLATE.md"
    mkdir "$target_dir/.github"
    cp "$pr_template" "$target_dir/.github/PULL_REQUEST_TEMPLATE.md"

    # Add files and push to GitHub Project
    cd "$target_dir"
    mkdir .buddy
    cp $HOME/buddy_template_dev.yml .buddy/buddy.dev.fixed.yml
    sed -i '' -e "s/#WPEDEVENV#/$install_dev/g" ".buddy/buddy.dev.fixed.yml"
    sed -i '' -e "s/#DOMAIN#/$domain/g" ".buddy/buddy.dev.fixed.yml"
    cp $HOME/buddy_template_stg.yml .buddy/buddy.stg.fixed.yml
    sed -i '' -e "s/#WPESTGENV#/$install_stg/g" ".buddy/buddy.stg.fixed.yml"
    sed -i '' -e "s/#DOMAIN#/$domain/g" ".buddy/buddy.stg.fixed.yml"
    cp $HOME/buddy_template_prd.yml .buddy/buddy.prd.fixed.yml
    sed -i '' -e "s/#WPEPRDENV#/$install_prd/g" ".buddy/buddy.prd.fixed.yml"
    sed -i '' -e "s/#DOMAIN#/$domain/g" ".buddy/buddy.prd.fixed.yml"
    git add .buddy/buddy.dev.fixed.yml; git commit -m "Dev Deployment Pipeline Configuration"
    git add .buddy/buddy.stg.fixed.yml; git commit -m "Dev Deployment Pipeline Configuration"
    git add .buddy/buddy.prd.fixed.yml; git commit -m "Dev Deployment Pipeline Configuration"
    git add .
    git commit -m "Initial Setup"
    git branch -M prd
    git push --set-upstream origin prd
    git checkout -b stg
    git push --set-upstream origin stg
    git checkout prd
    git checkout -b dev
    git push --set-upstream origin dev
    git checkout prd

    sleep 2

    # Add Teams to GitHub Project
    curl -L -X PUT -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/teams/9147126/repos/$org/${project_name// /-}" -d '{"permission":"admin"}'
    curl -L -X PUT -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/teams/5436628/repos/$org/${project_name// /-}" -d '{"permission":"push"}'
    curl -L -X PUT -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/teams/5589578/repos/$org/${project_name// /-}" -d '{"permission":"push"}'

    sleep 2

    # Configure Branch protection rule for development branch, configure the repository, and setup autolinks
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "prd","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/prd"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "stg","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/stg"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "dev","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/dev"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    gh repo edit $org/${project_name// /-} --delete-branch-on-merge --enable-issues=false --enable-wiki=false --enable-projects=false --enable-discussions=false
    url="https://api.github.com/repos/$org/${project_name// /-}/autolinks"
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" $url -d '{"key_prefix":"TICKET-","url_template":"https://intranet.americaneagle.com/tickets/view.asp?MODE=view&TICKET_ID=<num>","is_alphanumeric":false}'
    echo "Is this a JIRA project? (y/n)"
    read jira
    if [ "$jira" == "y" ]; then
    echo "Enter the JIRA project key:"
    read jira_key
    # curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization : Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" $url -d '{"key_prefix":"'$jira_key'-","url_template":"https://americaneagle.atlassian.net/browse/'$jira_key'-<num>","is_alphanumeric":true}'
    key_prefix='"key_prefix":"'${jira_key}'-"'
    url_template='"url_template":"https://americaneagle.atlassian.net/browse/'${jira_key}'-<num>"'
    fi
    echo "Autolinks setup completed."
    echo "Repository setup completed."
}

# Function to handle update
update_setup() {
    echo "Updating repository configuration for Production and Staging"
    install_prd="$1"
    install_stg="$2"
    install_dev="$3"
    project_name="$4"
    domain="$5"
    org="AEWP"

    readme_template="$HOME/README_TEMPLATE.md"

    if [ ! -f "$readme_template" ]; then
    echo "Error: README_TEMPLATE.md not found at $readme_template"
    exit 1
    fi

    cd ~/Downloads
    rm -rf $install_prd
    gh repo clone $org/${project_name// /-} $install_prd

    target_dir="$HOME/Downloads/$install_prd"
    cd $target_dir
    git checkout -b update/configure-pipelines
    rsync -arvp "$install_prd@$install_prd.ssh.wpengine.net:~/sites/$install_prd/wp-content/themes/" "$target_dir/themes/" --exclude="kadence/" --exclude="twenty*/" --exclude="astra/" --exclude="g5_helium/" --exclude="genesis/"

    # Add README.md to the project folder
    readme="$target_dir/README.md"
    if [ -f "$readme_template" ]; then
    cp "$readme_template" "$readme"
    sed -i '' -e "s/#Project Name#/$project_name/g" "$readme"
    sed -i '' -e "s/#Install Name#/$install_prd/g" "$readme"
    else
    echo "Error: README_TEMPLATE.md not found at $readme_template"
    exit 1
    fi

    # Add .gitignore to the project folder
    gitignore_template="$HOME/.gitignore_template"
    cp "$gitignore_template" "$target_dir/.gitignore"

    # Add .editorconfig to the project folder
    editorconfig_template="$HOME/.editorconfig_template"
    if [ -f "$editorconfig_template" ]; then
    cp "$editorconfig_template" "$target_dir/.editorconfig"
    git add .editorconfig
    else
    echo "Warning: .editorconfig not found at $editorconfig_template"
    fi

    #Add .vscode to the project folder.
    vscode_template="$HOME/.vscode_template/settings.json"
    if [ -f "$vscode_template" ]; then
    mkdir -p "$target_dir/.vscode"
    cp "$vscode_template" "$target_dir/.vscode/settings.json"
    git add .vscode/settings.json
    else
    echo "Warning: VSCode settings.json not found at $vscode_template"
    fi

    # Add PR Template to the project folder
    pr_template="$HOME/PULL_REQUEST_TEMPLATE.md"
    mkdir "$target_dir/.github"
    cp "$pr_template" "$target_dir/.github/PULL_REQUEST_TEMPLATE.md"

    # Add files and push to GitHub Project
    cd "$target_dir"
    cp $HOME/buddy_template_stg.yml .buddy/buddy.stg.fixed.yml
    sed -i '' -e "s/#WPESTGENV#/$install_stg/g" ".buddy/buddy.stg.fixed.yml"
    sed -i '' -e "s/#DOMAIN#/$domain/g" ".buddy/buddy.stg.fixed.yml"
    cp $HOME/buddy_template_prd.yml .buddy/buddy.prd.fixed.yml
    sed -i '' -e "s/#WPEPRDENV#/$install_prd/g" ".buddy/buddy.prd.fixed.yml"
    sed -i '' -e "s/#DOMAIN#/$domain/g" ".buddy/buddy.prd.fixed.yml"
    git add .buddy/buddy.stg.fixed.yml; git commit -m "Staging Deployment Pipeline Configuration"
    git add .buddy/buddy.prd.fixed.yml; git commit -m "Production Deployment Pipeline Configuration"
    git add .
    git commit -m "Refresh Code From Production"
    git push --set-upstream origin update/configure-pipelines
    git checkout dev
    git merge -X theirs update/configure-pipelines
    git push origin dev -f
    git checkout -b prd
    git push --set-upstream origin prd
    gh repo edit $org/${project_name// /-} --default-branch prd
    git checkout -b stg
    git push --set-upstream origin stg
    git checkout dev
    git reset --hard origin/prd
    git push --set-upstream origin dev
    git checkout prd
    git push -d origin update/configure-pipelines
    git branch -d update/configure-pipelines

    sleep 2

    # Configure Branch protection rule for production branch, and configure the repository
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "prd","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/prd"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "stg","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/stg"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "dev","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/dev"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    gh repo edit $org/${project_name// /-} --delete-branch-on-merge --enable-issues=false --enable-wiki=false --enable-projects=false --enable-discussions=false
    echo "Repository update completed. Be sure to remove existing dev branch rules and verify the new configuration."
}

# Function to handle development only setup
dev_only_setup() {
    echo "Setting up development environment"
    install_dev="$1"
    project_name="$2"
    org="AEWP"
    readme_template="$HOME/README_TEMPLATE.md"

    if [ ! -f "$readme_template" ]; then
    echo "Error: README_TEMPLATE.md not found at $readme_template"
    exit 1
    fi

    cd ~/Downloads
    gh repo create $org/${project_name// /-} --private -t americaneagle-com-servers
    gh repo clone $org/${project_name// /-} $install_dev

    target_dir="$HOME/Downloads/$install_dev"
    rsync -arvp "$install_dev@$install_dev.ssh.wpengine.net:~/sites/$install_dev/wp-content/themes/" "$target_dir/themes/" --exclude="kadence/" --exclude="twenty*/" --exclude="astra/" --exclude="g5_helium/" --exclude="genesis/"

    # Add README.md to the project folder
    readme="$target_dir/README.md"
    if [ -f "$readme_template" ]; then
    cp "$readme_template" "$readme"
    sed -i '' -e "s/#Project Name#/$project_name/g" "$readme"
    sed -i '' -e "s/#Install Name#/$install_dev/g" "$readme"
    else
    echo "Error: README_TEMPLATE.md not found at $readme_template"
    exit 1
    fi

    # Add .gitignore to the project folder
    gitignore_template="$HOME/.gitignore_template"
    cp "$gitignore_template" "$target_dir/.gitignore"

    # Add .editorconfig to the project folder
    editorconfig_template="$HOME/.editorconfig_template"
    if [ -f "$editorconfig_template" ]; then
    cp "$editorconfig_template" "$target_dir/.editorconfig"
    git add .editorconfig
    else
    echo "Warning: .editorconfig not found at $editorconfig_template"
    fi

    #Add .vscode to the project folder.
    vscode_template="$HOME/.vscode_template/settings.json"
    if [ -f "$vscode_template" ]; then
    mkdir -p "$target_dir/.vscode"
    cp "$vscode_template" "$target_dir/.vscode/settings.json"
    git add .vscode/settings.json
    else
    echo "Warning: VSCode settings.json not found at $vscode_template"
    fi

    # Add PR Template to the project folder
    pr_template="$HOME/PULL_REQUEST_TEMPLATE.md"
    mkdir "$target_dir/.github"
    cp "$pr_template" "$target_dir/.github/PULL_REQUEST_TEMPLATE.md"

    # Add files and push to GitHub Project
    cd "$target_dir"
    mkdir .buddy
    cp $HOME/buddy_template_dev.yml .buddy/buddy.dev.fixed.yml
    sed -i '' -e "s/#WPEDEVENV#/$install_dev/g" ".buddy/buddy.dev.fixed.yml"
    git add .buddy/buddy.dev.fixed.yml; git commit -m "Dev Deployment Pipeline Configuration"
    git add .
    git commit -m "Initial Setup"
    git branch -M dev
    git push --set-upstream origin dev

    sleep 2

    # Add Teams to GitHub Project
    curl -L -X PUT -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/teams/9147126/repos/$org/${project_name// /-}" -d '{"permission":"admin"}'
    curl -L -X PUT -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/teams/5436628/repos/$org/${project_name// /-}" -d '{"permission":"push"}'
    curl -L -X PUT -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/teams/5589578/repos/$org/${project_name// /-}" -d '{"permission":"push"}'

    sleep 2

    # Configure Branch protection rule for development branch, configure the repository, and setup autolinks
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/$org/${project_name// /-}/rulesets -d '{"name": "dev","target": "branch","source_type": "Repository","source": "'${project_name// /-}'","enforcement": "active","conditions": {"ref_name": {"exclude": [],"include": ["refs/heads/dev"]}},"rules": [{"type": "deletion"},{"type": "non_fast_forward"},{"type": "creation"},{"type": "required_linear_history"},{"type": "pull_request","parameters": {"required_approving_review_count": 1,"dismiss_stale_reviews_on_push": true,"require_code_owner_review": false,"require_last_push_approval": false,"required_review_thread_resolution": true}}],"bypass_actors": [{"actor_id": 5,"actor_type": "RepositoryRole","bypass_mode": "always"},{"actor_id": 1,"actor_type": "OrganizationAdmin","bypass_mode": "always"}]}'
    gh repo edit $org/${project_name// /-} --delete-branch-on-merge --enable-issues=false --enable-wiki=false --enable-projects=false --enable-discussions=false
    url="https://api.github.com/repos/$org/${project_name// /-}/autolinks"
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" $url -d '{"key_prefix":"TICKET-","url_template":"https://intranet.americaneagle.com/tickets/view.asp?MODE=view&TICKET_ID=<num>","is_alphanumeric":false}'
    echo "Is this a JIRA project? (y/n)"
    read jira
    if [ "$jira" == "y" ]; then
    echo "Enter the JIRA project key:"
    read jira_key
    key_prefix='"key_prefix":"'${jira_key}'-"'
    url_template='"url_template":"https://americaneagle.atlassian.net/browse/'${jira_key}'-<num>"'
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" $url -d '{'${key_prefix}','${url_template}',"is_alphanumeric":false}'
    fi
    echo "Autolinks setup completed."
    echo "Repository setup completed."
}

# Function to add rules to an existing project
add_rules() {
    org="AEWP"
    project_name="$1"
    echo "Adding rules to $project_name"
    check_rule_sets "$org" "$project_name"
}

# Function to get rule set
get_rule_set() {
    org=$1
    project_name=$2
    branch_name=$3
    api_url="https://api.github.com/repos/$org/${project_name// /-}/rulesets"
    response=$(curl -L -X GET -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "$api_url")
    echo "$response" | grep -q "\"ref_name\": \"$branch_name\""
}

# Function to create or update rule set
setup_rule_set() {
    org=$1
    project_name=$2
    branch_name=$3
    if get_rule_set "$org" "$project_name" "$branch_name"; then
        echo "Rule set exists for $branch_name exists. Updating..."
        rule_set_id=$(curl -s -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/$org/${project_name// /-}/rulesets" | jq -r ".[] | select(.conditions.ref_name.include | index(\"refs/heads/$branch_name\")) | .id")
        if [ -z "$rule_set_id" ]; then
            update_rule_set "$org" "$project_name" "$branch_name"
        else
            echo "Error: Rule set ID not found for $branch_name"
        fi
    else
        echo "Rule set does not exist for $branch_name. Creating..."
        create_rule_set "$org" "$project_name" "$branch_name"
    fi
}

create_rule_set() {
    org=$1
    project_name=$2
    branch_name=$3
    api_url="https://api.github.com/repos/$org/${project_name// /-}/rulesets"
    data=$(cat <<EOF
{
    "bypass_actors": [
        {
            "actor_id": 5,
            "actor_type": "RepositoryRole",
            "bypass_mode": "always"
        },
        {
            "actor_id": 1,
            "actor_type": "OrganizationAdmin",
            "bypass_mode": "always"
        }
    ],
    "conditions": {
        "ref_name": {
            "exclude": [],
            "include": ["refs/heads/$branch_name"]
        }
    },
    "enforcement": "active",
    "name": "$branch_name",
    "rules": [
        {
            "type": "deletion"
        },
        {
            "type": "non_fast_forward"
        },
        {
            "type": "creation"
        },
        {
            "type": "required_linear_history"
        },
        {
            "parameters": {
                "dismiss_stale_reviews_on_push": true,
                "require_code_owner_review": false,
                "require_last_push_approval": false,
                "required_approving_review_count": 1,
                "required_review_thread_resolution": true
            },
            "type": "pull_request"
        }
    ],
    "source": "${project_name// /-}",
    "source_type": "Repository",
    "target": "branch"
}
EOF
)
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/$org/${project_name// /-}/rulesets" -d "$data"
}

update_rule_set() {
    org=$1
    project_name=$2
    branch_name=$3
    rule_set_id=$4
    data=$(cat <<EOF
{
  "name": "$branch_name",
  "target": "branch",
  "source_type": "Repository",
  "source": "${project_name// /-}",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/$branch_name"]
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "creation"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    },
    {
      "actor_id": 1,
      "actor_type": "OrganizationAdmin",
      "bypass_mode": "always"
    }
  ]
}
EOF
)
    curl -L -X PATCH -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/$org/${project_name// /-}/rulesets/$rule_set_id" -d "$data"
}

# Function to check rule sets
check_rule_sets() {
    org="AEWP"
    project_name="$1"
    echo "Checking rules for $project_name"
    echo "Checking PRD rule set..."
    setup_rule_set "$org" "$project_name" "prd"
    echo "Rule set for PRD defined."
    echo "Checking STG rule set..."
    setup_rule_set "$org" "$project_name" "stg"
    echo "Rule set for STG defined."
    echo "Checking DEV rule set..."
    setup_rule_set "$org" "$project_name" "dev"
    echo "Rule set for DEV defined."
}

# Conditional execution based on arguments
if [ ! -z "$new_arg" ]; then
    new_setup "$install_prd" "$install_stg" "$install_dev" "$project_name" "$domain"
fi

if [ ! -z "$update_arg" ]; then
    update_setup "$install_prd" "$install_stg" "$install_dev" "$project_name" "$domain"
fi

if [ ! -z "$dev_only_arg" ]; then
    dev_only_setup "$install_dev" "$project_name"
fi

if [ ! -z "$add_rules_arg" ]; then
    echo "Adding rules to $project_name"
    check_rule_sets "$project_name"
fi
