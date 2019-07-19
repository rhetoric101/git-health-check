#!/usr/bin/bash
########################################################################
# git_check_x.bash
#
# DESCRIPTION
# The purpose of the script is to discover why some Tortoise GIT sessions do not see changed 
# files. Here is what the program does:
#   -It finds all uncommitted files in /c/git.
#   -If all files are committed, the script can clone your repository to /c/git_diagnostics.
#   -After the clone is finished, the script can run a comparison (DIFF).
#   -The comparison results are saved in /c/git/diff.txt.
#
#To execute this script:
#   1. Insert git_check_x.bash into a drive you can see in Explorer, such as /c/git or /h/.
#   2. Open a Git Bash session.
#   3. Execute the script by typing the following at the prompt and pressing ENTER:
#      ./git_check_x.bash (insert the correct version number for 'x')
#   4. When the script is finished, you can review the comparison results in /c/git/diff.txt.
#
# HISTORY: 
# Version  Who              When         What
# -------  ---------------  -----------  -----------------------------------
#   1      Rob Siebens      17-Sept-2018 Created script
#   2      Rob Siebens      21-Sept-2018 Excluded MadCap-hosted projects from uncommitted list.
#                                        Changed script so it can run from other drives, such as /h/.
#   3      Rob Siebens      25-Sept-2018 Added support for Git directories containing spaces.
#                                        Added a deletion option to remove an old /c/git_diagnostics directory.
#                                        Added a deletion option to remove the cloned directory as a cleanup step.
#   4      Rob Siebens      3-Oct-2018   Now checking for files in three states:
#                                             --Changed files that are unstaged for commit
#                                             --Files staged for commit
#                                             --Files committed but not pushed to remote
#                                        Excluded same directories as Dan's spec.
#                                        Excluded the trta-idpt project
#   5      Rob Siebens      4-Oct-2018   Removed unpushed test. Now testing if remote pull is required.
#                                        Included temporary diagnostic when doing ls-files to diagnose failure on Devin's computer.
#   6      Rob Siebens      8-Oct-2018   Added support for running from a batch file.
#   7      Rob Siebens      11-Oct-2018  Fixed bug when filtering out MadCap Central and trta-idpt projects.
#   8      Rob Siebens      12-Oct-2018  Fixed bug in clone section and removed directory filters from DIFF (because they don't work!).
#   9      Rob Siebens      17-Oct-2018  Added the following filters to DIFF: *.js and *.skl
#   10     Rob Siebens      30-Oct-2018  Made fixes so the script now looks for the following:
#                                             --Changed files that are unstaged for commit (using original ls-files query)
#                                             --Files staged for commit (using new GIT query that does not overlap with ls-files)
#                                             --Files committed but not pushed to remote (using new GIT log query that doesn't look at remote)
#                                             --Check for remote files you need to pull down from other users.
########################################################################


check_directories() # FUNCTION TO FIND UNSTAGED, STAGED, AND COMMITTED FILES
{
     IFS=$'\t\n' #Set internal field separator so it ignores spaces in directory names.
	 directory_array=( $(ls -d /c/git/*/) )
     directory_array_length=${#directory_array[@]}
	 directory_array_filtered=()
	 
	 #Go through the dirctory array and remove any directories hosted in Madcap Central:
	 for (( h=0; h<${directory_array_length}; h++ )); 
	      
	      do                
               project_url_1=$(grep -o 'https:*.*.git' ${directory_array[$h]}.git/config) #Extract URL to test for whether it is a Central or trta-idpt project to ignore.

               if [[ $project_url_1 !=  *"madcapcentral.com"* ]] && [[ $project_url_1 !=  *"trta-idpt"* ]]
                    then  
					     #Push filtered results into a new directory array called directory_array_filtered.
                         directory_array_filtered+=(${directory_array[$h]})
						 directory_array_filtered_length=${#directory_array_filtered[@]}                         						 
               fi
				
	      done
		  
	 # Find unstaged, changed files that have been part of a project.
	 echo " "
	 echo " "
	 echo " "
     echo "=================================================="
     echo "LOOKING FOR UNSTAGED CHANGES..."
     echo "=================================================="	 


     for (( i=0; i<${directory_array_filtered_length}; i++ )); 
          do			
               # Run git ls-files -m to find unstaged changes and then push results into a new array called unstaged_files_array.

               unstaged_files_array=($(git -C ${directory_array_filtered[$i]} ls-files -m) ) 
               unstaged_files_array_length=${#unstaged_files_array[@]}			
			
               if [ ${unstaged_files_array_length} -gt 0 ] 
                    then				
                         unstaged_flag="no_clone"	#Set flag to stop script if there are unstaged changed.
               fi

               for (( j=0; j<${unstaged_files_array_length}; j++ ));
                    do	
                         printf '%s\n' " "
						 printf '%s\n' "Directory Name: ${directory_array_filtered[$i]}"  
                         printf '%s\n' "--------------------------------------------------"		 
                         printf '%s\n' "${unstaged_files_array[$j]}"	
               done
          done
		  
	 # Find staged files waiting to be committed.	
	 echo " "
	 echo " "
	 echo " "
     echo "=================================================="
     echo "LOOKING FOR STAGED CHANGES READY TO COMMIT..."
     echo "=================================================="	 
	
		  
     for (( k=0; k<${directory_array_filtered_length}; k++ )); 
          do			
               #Run git diff on cache and then push results into a new array called uncommitted_files_array.
               uncommitted_files_array=($(git -C ${directory_array_filtered[$k]} diff --name-only --cached) ) 

               uncommitted_files_array_length=${#uncommitted_files_array[@]}			
			
               if [ ${uncommitted_files_array_length} -gt 0 ] 
                    then				
                         uncommitted_flag="no_clone"	#Set flag to stop script if there are staged changes.
               fi

               for (( m=0; m<${uncommitted_files_array_length}; m++ ));
                    do	
                         printf '%s\n' " "
						 printf '%s\n' "Directory Name: ${directory_array_filtered[$k]}"  
                         printf '%s\n' "--------------------------------------------------"					 
                         printf '%s\n' "${uncommitted_files_array[$m]}"	
               done
          done
		  
	 # Find committed files waiting to be pushed.	
	 echo " "
	 echo " "
	 echo " "
     echo "=================================================="
     echo "LOOKING FOR COMMITTED CHANGES READY TO PUSH..."
     echo "=================================================="	 
	
		  
     for (( k=0; k<${directory_array_filtered_length}; k++ )); 
          do			
               #Run git log and then push results into a new array called unpushed_files_array.
               unpushed_files_array=($(git -C ${directory_array_filtered[$k]} log --name-only --pretty=format: HEAD --not origin/master) ) 

               unpushed_files_array_length=${#unpushed_files_array[@]}			
			
               if [ ${unpushed_files_array_length} -gt 0 ] 
                    then				
                         unpushed_flag="no_clone"	#Set flag to stop script if there are staged changes.
               fi

               for (( m=0; m<${unpushed_files_array_length}; m++ ));
                    do	
                         printf '%s\n' " "
						 printf '%s\n' "Directory Name: ${directory_array_filtered[$k]}"  
                         printf '%s\n' "--------------------------------------------------"					 
                         printf '%s\n' "${unpushed_files_array[$m]}"	
               done
          done
		  
	 # Check if any remote changes need to be pulled down.
	 echo " "
	 echo " "
	 echo " "
     echo "=================================================="
     echo "CHECKING IF YOU NEED TO PULL REMOTE CHANGES..."
     echo "=================================================="	 

		  
     for (( n=0; n<${directory_array_filtered_length}; n++ )); 
          do			
               #Run remote update and then push results into a new array called need_pull_files_array.
			   git -C ${directory_array_filtered[$n]} remote update &>/c/git/remote_update_results.txt #Send scary output to a file
               need_pull_files_array=($(git -C ${directory_array_filtered[$n]} status -uno ) ) 
               need_pull_files_array_length=${#need_pull_files_array[@]}	

               for (( p=0; p<${need_pull_files_array_length}; p++ )); #Loop through output of git status to find if user needs to pull.
                    do	
					     
					     if [[ "${need_pull_files_array[$p]}" = *"Your branch is behind"* ]]
						      then
							       pull_flag="no_clone" #Set flag to stop script if user needs to pull.
                                   printf '%s\n' " " 
						           printf '%s\n' "Directory Name: ${directory_array_filtered[$n]}" 
                                   printf '%s\n' "--------------------------------------------------"
						           printf '%s\n' "Results: ${need_pull_files_array[$p]}"  
                                   printf '%s\n' "--------------------------------------------------"							 
                         fi 								   
                    done
          done

     if [[ "${unstaged_flag}" = "no_clone"  || "${uncommitted_flag}" = "no_clone"  || "${unpushed_flag}" = "no_clone" || "${pull_flag}" = "no_clone" ]] 
          then
		       while true; do
			        echo " "
                    echo "HOUSEKEEPING ALERT: You have some files to stage, commit, or pull." 
                    read -p "Press X to exit so you can fix these issues before rerunning the script: " lets_exit 							   
					     case $lets_exit in
                              [Xx]* )
                                   exit;;
                                  * ) echo "Please enter X to exit."
                         esac
               done

                    echo " "
					echo " "
                    echo "You have some files to stage, commit, push, or pull down before you continue. Press X to exit "
                    echo "uncommitted GIT files listed above, or you need to"
                    echo "pull down changes from other users of your project."
                    echo " "
                    echo "Restart this script after you commit those files."
                    exit
         else
              echo " "
              echo "It looks like all your GIT files are committed and pushed"
              echo "to the repository."
              echo " "
     fi
}

git_clone() # FUNCTION TO CLONE PROJECTS
{
     while true; do
          read -p "Is it OK if this script clones your GIT projects to c:\git_diagnostics (Enter Y or N)?  " yn
		  echo " "
		  
          case $yn in
               [Yy]* ) 
			        if [ -d /c/git_diagnostics ]
			              then
						       echo "It looks like you have already run this script because "
		                       echo "the script found the directory /c/git_diagnostics."
							   echo " "

                               while true; do	
                                    read -p "Enter D to delete the old directory before cloning or X to exit. " dx							   
							        case $dx in
							             [Dd]* )
									          rm -rf /c/git_diagnostics
									          break;;
									     [Xx]* ) exit;;
									     * ) echo "Please enter D or X."
                                    esac
                               done
						  
					fi

                         for (( m=0; m<${directory_array_filtered_length}; m++ ));
                              do										  
                              project_url_2=$(grep -o 'https:*.*.git' ${directory_array_filtered[$m]}/.git/config) #Extract from git config file the URL for each project to clone.
							  
						           if [[ $project_url_2 !=  *"madcapcentral.com"* ]] && [[ $project_url_2 !=  *"trta-idpt"* ]]  #Exclude projects that live in MadCap Central or are trta-idpt.
						                then									
						                     git -C ${directory_array_filtered[$m]} clone ${project_url_2} /c/git_diagnostics/${directory_array_filtered[$m]} # Use this to suppress stdout: &>/c/git/diagnostic_clone.txt
                                   fi									   
                         done
                         break;;
					
               [Nn]* ) exit;;
               * ) echo "Please answer Y or N.";;
          esac
     done
}

git_diff() # FUNCTION TO EXECUTE DIFF

{
     while true; do
	      echo " "
          read -p "Is it OK if the script executes a file comparison and saves the results in c:\git\diff.txt (Enter Y or N)? " yn

          case $yn in
               [Yy]* ) 
		            echo " "
		            echo "While you wait for the comparison, check out these tips about understanding the results: "
		            echo " "
		            echo "--The less-than symbol (<) refers to changes in c:\git (left file)."
                    echo "--The greater-than symbol (>) refers to changes in c:\git_diagnostics (right file)."
		            echo " "
		            echo "Here are some examples and explanations: "
		            echo "     - Add (a): '4a5' means line 5 in the right file was added to line 4."
		            echo "     - Change (c): '3c3' means a change was made in line 3."
		            echo "     - Change (c):'3,4c3,4' means a change has been made somewhere in lines 3 and 4."
		            echo "     - Delete (d):'4d3' means the 4th line in the left file was deleted in the right file."
		            echo "     - Change (c): '3,4c3' means lines 3 and 4 in the left file now are line 3 in the right file."
		            echo "     - Solitary File (Only in...): This means a file is in one directory or the other--not both."
		            echo " "
					echo "OK, your comparison results are below (and in the file /c/git/diff.txt):"
					
                    diff -r \
                    --exclude=".git" \
                    --exclude="*.css" \
                    --exclude="*.scss" \
                    --exclude="*.svg" \
                    --exclude="*.png" \
                    --exclude="*.jpg" \
                    --exclude=".gitignore" \
                    --exclude="assetinfo.json" \
                    --exclude="*.less" \
                    --exclude="*.js" \
                    --exclude="*.skl" \
                    /c/git \
                    /c/git_diagnostics/c/git  | tee /c/git/diff.txt	
                     
                    break;;
               [Nn]* ) exit;;
               * ) echo "Please answer Y or N.";;
          esac
     done
}
   
git_remove() #FUNCTION TO REMOVE /c/git_diagnostics directory

{
     while true; do
          read -p "Would you like the script to remove the /c/git_diagnostics directory (Enter Y or N)?  " ab
		  echo " "
		  
          case $ab in
               [Yy]* ) 
			        if [ -d /c/git_diagnostics ]
			              then
						       rm -rf /c/git_diagnostics
							   echo "The script is finished!"
                    fi
                    exit;;					
               [Nn]* ) echo "OK, the script is leaving /c/git_diagnostics in place."
			        exit;;
               * ) echo "Please answer Y or N.";;
          esac
     done
} 
#############
# Main
#############

check_directories

git_clone

git_diff

git_remove