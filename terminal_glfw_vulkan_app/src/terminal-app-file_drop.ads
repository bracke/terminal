with System;

package Terminal.App.File_Drop is
   Max_Path_Length : constant := 1_024;
   Max_Pending_Paths : constant := 16;

   type Path_Value is private;
   function Text (Value : Path_Value) return String;

   type Install_Status is (Installed, Invalid_Window);
   procedure Initialize
     (Window : System.Address;
      Status : out Install_Status);
   procedure Finalize (Window : System.Address);
   procedure Poll (Value : out Path_Value; Available : out Boolean);
   procedure Enqueue (Path : String);
   function Overflow_Count return Natural;

private
   type Path_Value is record
      Length : Natural range 0 .. Max_Path_Length := 0;
      Data : String (1 .. Max_Path_Length) := (others => ASCII.NUL);
   end record;
end Terminal.App.File_Drop;
