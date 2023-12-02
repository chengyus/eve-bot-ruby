eve-bot-ruby
------------------------------------------

This is just a repo for converting this eve-memory-reader to a potential Ruby-based code (currently using glimmer-dsl-swt gem). Although it is pure Ruby code, please read up on glimmer-dsl-swt gem documentation as it require Java, Jruby, and a Windows-flavored Ruby to setup. And the Git, FFI DLL support (which requires RUBY\_DLL\_PATH environment variable to be set.  And personal preference I would use Ruby32-x64's ucrt64 shell (which was weird because it requires various windows execute path to be set in the Bash init such as .bash\_profile and also maybe ridk (not quite sure what's it for, but it seems to provide some sort of Ruby integrated development kit, current usage is mostly for the ls command before the ucrt64 window border with a cygwin-like border and paste ability. But yes, a very C-like development place with 64bit support).  

The goal of this project is basically to reproduce the GUI functionality of that Python Flask application using Ruby and Glimmer-DSL-SWT. I thought about using Opal (and Rails), but this applicaiton just need to be able to access windows PID and parse that UI-tree and do similar GUI input and output. Currently, I am still new to that Glimmer DSL syntax, so development is very slow.  It almost felt like designing a new app using Glimmer DSL is faster than concerting the old app with AI. But I currently have the SHELL titled window converted. Everything else has lots of errors.

Contributing to eve-bot-ruby
------------------------------------------
- currently, I am just developing this for myself. But I am leaving the following as-is for any potential fork.

-   Check out the latest master to make sure the feature hasn't been
    implemented or the bug hasn't been fixed yet.
-   Check out the issue tracker to make sure someone already hasn't
    requested it and/or contributed it.
-   Fork the project.
-   Start a feature/bugfix branch.
-   Commit and push until you are happy with your contribution.
-   Make sure to add tests for it. This is important so I don't break it
    in a future version unintentionally.
-   Please try not to mess with the Rakefile, version, or history. If
    you want to have your own version, or is otherwise necessary, that
    is fine, but please isolate to its own commit so I can cherry-pick
    around it.

Copyright
---------

Copyright (c) 2023 Joseph Sung. See
LICENSE.txt for further details.
