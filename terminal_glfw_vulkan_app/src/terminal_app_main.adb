with Ada.Command_Line;
with Terminal.App.Main_Loop;

procedure Terminal_App_Main is
begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1)'Length > 12
     and then Ada.Command_Line.Argument (1)
       (1 .. 12) = "--workspace="
   then
      Terminal.App.Main_Loop.Run
        (Ada.Command_Line.Argument (1)
           (13 .. Ada.Command_Line.Argument (1)'Last));
   else
      Terminal.App.Main_Loop.Run;
   end if;
end Terminal_App_Main;

