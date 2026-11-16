with AUnit.Assertions;
with System;
with Terminal.App.File_Drop;

procedure File_Drop_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.File_Drop.Install_Status;
   Value : Terminal.App.File_Drop.Path_Value;
   Available : Boolean;
   Status : Terminal.App.File_Drop.Install_Status;
begin
   Terminal.App.File_Drop.Initialize (System.Null_Address, Status);
   Assert (Status = Terminal.App.File_Drop.Invalid_Window,
           "null native window is rejected");
   Terminal.App.File_Drop.Enqueue ("/tmp/a file.txt");
   Terminal.App.File_Drop.Poll (Value, Available);
   Assert
     (Available
      and then Terminal.App.File_Drop.Text (Value) = "/tmp/a file.txt",
      "dropped path survives bounded callback queue");
   Terminal.App.File_Drop.Poll (Value, Available);
   Assert (not Available, "drop queue drains");
end File_Drop_Smoke;
