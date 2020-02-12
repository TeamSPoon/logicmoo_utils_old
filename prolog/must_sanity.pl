/* Part of LogicMOO Base Logicmoo Debug Tools
% ===================================================================
% File '$FILENAME.pl'
% Purpose: An Implementation in SWI-Prolog of certain debugging tools
% Maintainer: Douglas Miles
% Contact: $Author: dmiles $@users.sourceforge.net ;
% Version: '$FILENAME.pl' 1.0.0
% Revision: $Revision: 1.1 $
% Revised At:  $Date: 2002/07/11 21:57:28 $
% Licience: LGPL
% ===================================================================
*/

:- module(must_trace,
   [
      must/1, % Goal must succeed at least once once
      must_once/1, % Goal must succeed at most once
      must_det/1, % Goal must succeed determistically
      sanity/1,  % like assertion but adds trace control
      nop/1, % syntactic comment
      scce_orig/3,
      must_or_rtrace/1
    ]).

:- meta_predicate
        must(0),
        must_once(0),
        must_det(0),
        nop(*),
        sanity(0),
        must_or_rtrace(0),
        scce_orig(0,0,0).

:- set_module(class(library)).
% % % OFF :- system:use_module(library(logicmoo_utils_all)).

:- system:reexport(library(debug),[debug/3]).
:- system:reexport(library(logicmoo_common)).
 
% TODO Make a speed,safety,debug Triangle instead of these flags
:- create_prolog_flag(runtime_must,debug,[type(term)]).


%! must(:Goal) is nondet.
%
% Goal must succeed at least once once
%
% Wrap must/1 over parts of your code you do not trust
% If your code fails.. it will rewind to your entry block (at the scope of this declaration) and invoke rtrace/1 .
% If there are 50 steps to your code, it will save you from pushing `creep` 50 times.  
% Instead it turns off the leash to allow you to trace with your eyeballs instead of your fingers.
%
%% must( :Goal) is semidet.
%
% Must Be Successfull.
%

must(Goal):- (Goal*->true;must_0(Goal)).
must_0(Goal):- quietly(get_must(Goal,MGoal))-> call(MGoal).

must_or_rtrace(P):- call(P) *-> true ; rtrace(P).

%% get_must( ?Goal, ?CGoal) is semidet.
%
% Get Must Be Successfull.
%

get_must(Goal,CGoal):- (skipWrapper ; tlbugger:skipMust),!,CGoal = Goal.
get_must(M:Goal,M:CGoal):- must_be(nonvar,Goal),!,get_must(Goal,CGoal).
get_must(quietly(Goal),quietly(CGoal)):- current_prolog_flag(runtime_safety,3), !, get_must(Goal,CGoal).
get_must(quietly(Goal),CGoal):- !,get_must((quietly(Goal)*->true;Goal),CGoal).
get_must(Goal,CGoal):- (tlbugger:show_must_go_on),!,CGoal=must_keep_going(Goal).
get_must(Goal,CGoal):- hide_non_user_console,!,get_must_type(rtrace,Goal,CGoal).
get_must(Goal,CGoal):- current_prolog_flag(runtime_must,How), How \== none, !, get_must_type(How,Goal,CGoal).
get_must(Goal,CGoal):- current_prolog_flag(runtime_debug,2), !, 
   (CGoal = (on_x_debug(Goal) *-> true; debugCallWhy(failed(on_f_debug(Goal)),Goal))).
get_must(Goal,CGoal):-
   (CGoal = (catchv(Goal,E,
     ignore_each(((dumpST_error(must_ERROR(E,Goal)), %set_prolog_flag(debug_on_error,true),
         rtrace(Goal),nortrace,dtrace(Goal),badfood(Goal)))))
         *-> true ; (dumpST,ignore_each(((dtrace(must_failed_F__A__I__L_(Goal),Goal),badfood(Goal))))))).


get_must_type(speed,Goal,Goal).
get_must_type(warning,Goal,show_failure(Goal)).
get_must_type(rtrace,Goal,on_f_rtrace(Goal)).
get_must_type(keep_going,Goal,must_keep_going(Goal)).
get_must_type(retry,Goal,must_retry(Goal)).
get_must_type(How,Goal,CGoal):- 
     (How == assertion -> CGoal = (Goal*->true;call(prolog_debug:assertion_failed(fail, must(Goal))));
     (How == error ; true ) 
       -> CGoal = (Goal*-> true; throw(failed_must(Goal)))).

must_retry(Call):- 
   (repeat, (catchv(Call,E,(dmsg(E:Call),fail)) *-> true ; 
      catch((ignore(rtrace(Call)),leash(+all),visible(+all),
        repeat,wdmsg(failed(Call)),trace,Call,fail),'$aborted',true))).

must_keep_going(Goal):- set_prolog_flag(debug_on_error,false),
  (catch(Goal,E,
      xnotrace(((dumpST_error(sHOW_MUST_go_on_xI__xI__xI__xI__xI_(E,Goal)),ignore(rtrace(Goal)),badfood(Goal)))))
            *-> true ;
              xnotrace(dumpST_error(sHOW_MUST_go_on_failed_F__A__I__L_(Goal))),ignore(rtrace(Goal)),badfood(Goal)).

:- '$hide'(get_must/2).


xnotrace(G):- G,!.
:- '$hide'(xnotrace/2).

%! sanity(:Goal) is det.
%
% Optional Sanity Checking.
%
% like assertion/1 but adds trace control
%

sanity(_):- notrace(current_prolog_flag(runtime_safety,0)),!.
% sanity(_):-!.
sanity(Goal):- \+ tracing,
   \+ current_prolog_flag(runtime_safety,3),
   \+ current_prolog_flag(runtime_debug,0),
   (current_prolog_flag(runtime_speed,S),S>1),
   !,
   (1 is random(10)-> must(Goal) ; true).
sanity(Goal):- quietly(Goal),!.
sanity(_):- break, dumpST,fail.
sanity(Goal):- tlbugger:show_must_go_on,!,dmsg(show_failure(sanity,Goal)).
sanity(Goal):- setup_call_cleanup(wdmsg(begin_FAIL_in(Goal)),rtrace(Goal),wdmsg(end_FAIL_in(Goal))),!,dtrace(assertion(Goal)).

%! must_once(:Goal) is det.
%
% Goal must succeed at most once
%
must_once(Goal):- must(Goal),!.


%! must_det(:Goal) is det.
%
% Goal must succeed determistically
%

% must_det(Goal):- current_prolog_flag(runtime_safety,0),!,must_once(Goal).
must_det(Goal):- \+ current_prolog_flag(runtime_safety,3),!,must_once(Goal).
must_det(Goal):- must_once(Goal),!.
/*
must_det(Goal):- must_once((Goal,deterministic(YN))),(YN==true->true;dmsg(warn(nondet_exit(Goal)))),!.
must_det(Goal):- must_once((Goal,deterministic(YN))),(YN==true->true;throw(nondet_exit(Goal))).
*/

%! nop( :Goal) is det.
%
%  Comments out code without losing syntax
%
nop(_).


/*
scce_orig(Setup,Goal,Cleanup):-
   \+ \+ '$sig_atomic'(Setup), 
   catch( 
     ((Goal, deterministic(DET)),
       '$sig_atomic'(Cleanup),
         (DET == true -> !
          ; (true;('$sig_atomic'(Setup),fail)))), 
      E, 
      ('$sig_atomic'(Cleanup),throw(E))). 

:- abolish(system:scce_orig,3).


[debug]  ?- scce_orig( (writeln(a),trace,start_rtrace,rtrace) , (writeln(b),member(X,[1,2,3]),writeln(c)), writeln(d)).
a
b
c
d
X = 1 ;
a
c
d
X = 2 ;
a
c
d
X = 3.


*/

scce_orig(Setup0,Goal,Cleanup0):-
  xnotrace((Cleanup = notrace('$sig_atomic'(Cleanup0)),Setup = xnotrace('$sig_atomic'(Setup0)))),
   \+ \+ Setup, !,
   (catch(Goal, E,(Cleanup,throw(E)))
      *-> (notrace(tracing)->(notrace,deterministic(DET));deterministic(DET)); (Cleanup,!,fail)),
     Cleanup,
     (DET == true -> ! ; (true;(Setup,fail))).
      
/*
scce_orig(Setup,Goal,Cleanup):-
   \+ \+ '$sig_atomic'(Setup), 
   catch( 
     ((Goal, deterministic(DET)),
       '$sig_atomic'(Cleanup),
         (DET == true -> !
          ; (true;('$sig_atomic'(Setup),fail)))), 
      E, 
      ('$sig_atomic'(Cleanup),throw(E))). 
*/

% % % OFF :- system:reexport(library('debuggery/first')).
% % % OFF :- system:reexport(library('debuggery/ucatch')).
% % % OFF :- system:reexport(library('debuggery/dmsg')).
% % % OFF :- system:reexport(library('debuggery/rtrace')).
% % % OFF :- system:reexport(library('debuggery/bugger')).
% % % OFF :- system:reexport(library('debuggery/dumpst')).
% % % OFF :- system:reexport(library('debuggery/frames')).



:- ignore((source_location(S,_),prolog_load_context(module,M),module_property(M,class(library)),
 forall(source_file(M:H,S),
 ignore((functor(H,F,A),
  ignore(((\+ atom_concat('$',_,F),(export(F/A) , current_predicate(system:F/A)->true; system:import(M:F/A))))),
  ignore(((\+ predicate_property(M:H,transparent), module_transparent(M:F/A), \+ atom_concat('__aux',_,F),debug(modules,'~N:- module_transparent((~q)/~q).~n',[F,A]))))))))).

 

