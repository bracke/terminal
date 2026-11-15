package body GLFW_Vulkan.Input_Failures is
   package Input renames GLFW_Vulkan.Input;

   protected Failure_Log is
      procedure Note_Callback
        (Source : Input.Failure_Source; Exception_Name : String);
      procedure Note_Infrastructure
        (Source : Input.Failure_Source; Exception_Name : String);
      procedure Reset_Callbacks;
      procedure Reset_Infrastructure;
      function Snapshot return Input.Failure_Snapshot;
   private
      Callback_Count       : Natural := 0;
      Infrastructure_Count : Natural := 0;
      Last_Callback        : Input.Failure_Detail;
      Last_Infrastructure  : Input.Failure_Detail;
   end Failure_Log;

   protected body Failure_Log is
      procedure Store
        (Target         : out Input.Failure_Detail;
         Source         : Input.Failure_Source;
         Exception_Name : String)
      is
         Length : constant Input.Exception_Name_Length :=
           Input.Exception_Name_Length'Min
             (Exception_Name'Length, Input.Max_Exception_Name_Length);
      begin
         Target := (Source => Source, others => <>);
         Target.Name_Length := Length;
         if Length > 0 then
            Target.Exception_Name (1 .. Length) :=
              Exception_Name
                (Exception_Name'First .. Exception_Name'First + Length - 1);
         end if;
      end Store;

      procedure Note_Callback
        (Source : Input.Failure_Source; Exception_Name : String) is
      begin
         if Callback_Count < Natural'Last then
            Callback_Count := Callback_Count + 1;
         end if;
         Store (Last_Callback, Source, Exception_Name);
      end Note_Callback;

      procedure Note_Infrastructure
        (Source : Input.Failure_Source; Exception_Name : String) is
      begin
         if Infrastructure_Count < Natural'Last then
            Infrastructure_Count := Infrastructure_Count + 1;
         end if;
         Store (Last_Infrastructure, Source, Exception_Name);
      end Note_Infrastructure;

      procedure Reset_Callbacks is
      begin
         Callback_Count := 0;
         Last_Callback := (others => <>);
      end Reset_Callbacks;

      procedure Reset_Infrastructure is
      begin
         Infrastructure_Count := 0;
         Last_Infrastructure := (others => <>);
      end Reset_Infrastructure;

      function Snapshot return Input.Failure_Snapshot is
        ((Callback_Count        => Callback_Count,
          Callback_Detail       => Last_Callback,
          Infrastructure_Count  => Infrastructure_Count,
          Infrastructure_Detail => Last_Infrastructure));
   end Failure_Log;

   procedure Note_Callback
     (Source : Input.Failure_Source; Exception_Name : String) is
   begin
      Failure_Log.Note_Callback (Source, Exception_Name);
   end Note_Callback;

   procedure Note_Infrastructure
     (Source : Input.Failure_Source; Exception_Name : String) is
   begin
      Failure_Log.Note_Infrastructure (Source, Exception_Name);
   end Note_Infrastructure;

   procedure Reset_Callbacks is
   begin
      Failure_Log.Reset_Callbacks;
   end Reset_Callbacks;

   procedure Reset_Infrastructure is
   begin
      Failure_Log.Reset_Infrastructure;
   end Reset_Infrastructure;

   function Snapshot return Input.Failure_Snapshot is (Failure_Log.Snapshot);
end GLFW_Vulkan.Input_Failures;
