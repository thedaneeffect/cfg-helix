setopt AUTO_PUSHD           # Automatically push directories onto stack
setopt PUSHD_MINUS          # Swap meaning of cd +1 and cd -1
setopt CDABLE_VARS          # Allow cd to variable names
zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'
