#!/usr/bin/env escript
% -mode(compile).

main([]) ->
  io:format("Supported commands: init, updateschema, updatenodes~n");
main(Args) ->
	[] = os:cmd(epmd_path() ++ " -daemon"),
  case Args of
    [EtcPath1x,Cmd] ->
      EtcPath1 = EtcPath1x ++ "/etc"
  end,
  EtcPath2 = "{{platform_etc_dir}}",
  case filelib:is_file(EtcPath2++"/app.config") of
    true ->
      EtcPath = EtcPath2;
    false ->
      EtcPath = EtcPath1
  end,
  case filelib:is_file(EtcPath++"/app.config") of
    false ->
      io:format("Unable to find app.config at ~p~n",[EtcPath++"/app.config"]);
    true ->
      ok
  end,
  {ok,VmBin} = file:read_file(EtcPath++"/vm.args"),
  Lines = string:tokens(binary_to_list(VmBin),"\r\n"),
  [{node,Node}] = parse_args(Lines,[]),

  % io:format("Connecting to ~p~n",[Node]),
  case net_kernel:hidden_connect_node(Node) of
  	true ->
  		case net_adm:ping(Node) of
  			pang ->
  				io:format("ActorDB not responding~n"),
  				halt(1);
  			pong ->
  				ok
  		end;
  	_X ->
  		io:format("ActorDB not running~n"),
  		halt(1)
  end,
  case rpc:call(Node,actordb_cmd,cmd,[list_to_atom(Cmd),parse,EtcPath]) of
  	{ok,nochange} ->
  		io:format("No changes detected~n");
    {ok,Out} ->
    	io:format("~s~n",[Out]),
      case do_confirmation() of
        yes ->
          Result = rpc:call(Node,actordb_cmd,cmd,[list_to_atom(Cmd),commit,EtcPath]),
          io:format("~s~n",[Result]);
        no ->
          ok
      end;
    {_,E} ->
      io:format("Error: ~s~n",[E]);
    E ->
      io:format("Error: ~s~n",[E])
  end.



do_confirmation() ->
	case io:fread("Confirm change? (Y/N): ", "~a") of
		{ok,[y]} ->
			yes;
		{ok,[n]} ->
			no;
		_ ->
			do_confirmation()
	end.



parse_args([" "++Rem|T],L) ->
	parse_args([Rem|T],L);
parse_args(["#"++_|T],L) ->
	parse_args(T,L);
parse_args(["-name " ++ Namestr|T],L) ->
	Curname = rem_spaces(Namestr),
	{ok, _} = net_kernel:start([setname(Curname), longnames]),
	parse_args(T,[{node,list_to_atom(Curname)}|L]);
parse_args(["-sname " ++ Namestr|T],L) ->
	Curname = rem_spaces(Namestr),
	{ok, _} = net_kernel:start([setname(Curname), shortnames]),
	parse_args(T,[{node,list_to_atom(Curname)}|L]);
parse_args(["-setcookie "++N|T],L) ->
	erlang:set_cookie(node(), list_to_atom(rem_spaces(N))),
	parse_args(T,L);
parse_args([_|T],L) ->
  parse_args(T,L);
parse_args([],L) ->
	L.


setname(Namestr) ->
	{MS,S,MiS} = now(),
	Nm = integer_to_list(MS*1000000000000 + S*1000000 + MiS),
	case string:tokens(rem_spaces(Namestr),"@") of
		[_Name,Addr] ->
			list_to_atom(Nm++"@"++Addr);
		[_Name] ->
			list_to_atom(Nm)
	end.

rem_spaces(Str) ->
	lists:filter(fun(X) -> X /= $\s end,Str).

epmd_path() ->
  ErtsBinDir = filename:dirname(escript:script_name()),
  Name = "epmd",
  case os:find_executable(Name, ErtsBinDir) of
    false ->
      case os:find_executable(Name) of
        false ->
          io:format("Could not find epmd.~n"),
          halt(1);
        GlobalEpmd ->
          GlobalEpmd
      end;
    Epmd ->
      Epmd
  end.




