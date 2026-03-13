(( ${+commands[perl]} || ${+commands[cpan]} )) || return

export PERL_LOCAL_LIB_ROOT="${XDG_DATA_HOME}/perl"
export PERL_CPANM_HOME="${PERL_LOCAL_LIB_ROOT}/cpan"

export PERL5LIB="${PERL_CPANM_HOME}:${PERL_LOCAL_LIB_ROOT}/lib/perl5"

export PERL_MB_OPT="--install_base '${PERL_LOCAL_LIB_ROOT}'"
export PERL_MM_OPT="  INSTALL_BASE='${PERL_LOCAL_LIB_ROOT}'"

if (( ${+commands[cpan]} )); then
	alias cpan='cpan -j ${PERL_CPANM_HOME}/CPAN/MyConfig.pm'
fi
