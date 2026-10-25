package Terminal.App.ITerm2_Files is
   Max_Directory_Length : constant := 4_096;
   Max_File_Name_Length : constant := 255;

   type Download_Policy is record
      Enabled          : Boolean := False;
      Directory_Length : Natural range 0 .. Max_Directory_Length := 0;
      Directory        : String (1 .. Max_Directory_Length) := (others => ' ');
   end record;

   Disabled_Policy : constant Download_Policy := (others => <>);

   type Save_Status is
     (Save_Ok,
      Save_Disabled,
      Save_Invalid_Command,
      Save_Invalid_Name,
      Save_Invalid_Data,
      Save_Too_Large,
      Save_Allocation_Failed,
      Save_Directory_Unavailable,
      Save_Create_Failed,
      Save_Write_Failed);

   procedure Configure
     (Policy    : out Download_Policy;
      Enabled   : Boolean;
      Directory : String);

   function Default_Download_Directory return String;

   procedure Save
     (Command       : String;
      Policy        : Download_Policy;
      Maximum_Bytes : Positive;
      Status        : out Save_Status;
      Saved_Name    : out String;
      Saved_Length  : out Natural);
end Terminal.App.ITerm2_Files;
