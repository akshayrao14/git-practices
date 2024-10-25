#!/bin/bash
script_dir=$(dirname "$0")
# shellcheck disable=SC1091
source "$script_dir/helpers/spinner.sh"
# shellcheck disable=SC1091
source "$script_dir/helpers/helper_merge.sh"

########################################################################
# Helper functions - run one time migrations/scripts automatically
########################################################################
migrArtifactsRelPath="/.git/merge_into"
# shellcheck disable=SC2034
migrArtifactsAbsPath="${script_dir/\/scripts/$migrArtifactsRelPath}"

shownMigrationMessage=0
showMigrationMessage(){
if [ "$shownMigrationMessage" -eq 0 ]; then
        echo -e "${LOW_INTENSITY_TEXT}Running one-time migrations..."; RESET_FORMATTING
        shownMigrationMessage=1
    fi
}
########################################################################
# Helper functions - one time migrations
########################################################################

vscode_mergetool_migrations(){
    showMigrationMessage

    artifactFile="$migrArtifactsAbsPath/reset_vscode_mergetool_v1.dat"
    if [ ! -f "$artifactFile" ]; then

        mergetool_name=$(git config --get merge.tool)

        if [ "$mergetool_name" == "vscode" ]; then
            echo -e "${LOW_INTENSITY_TEXT_DIM}reset vscode mergetool settings"; RESET_FORMATTING
            set_vscode_mergetool
        fi
        
        touch "$artifactFile"
    fi
}

########################################################################
# Run migrations
########################################################################
runMigrations(){
    mkdir -p "$migrArtifactsAbsPath"
    vscode_mergetool_migrations
}

runMigrations