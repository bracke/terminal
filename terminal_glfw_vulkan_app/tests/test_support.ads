with Ada.Finalization;

package Test_Support is
   type Temporary_File is
     limited new Ada.Finalization.Limited_Controlled with private;
   procedure Reserve
     (Item      : in out Temporary_File;
      Prefix    : String;
      Directory : String := "/tmp");
   function Path (Item : Temporary_File) return String;

   type Temporary_Directory is
     limited new Ada.Finalization.Limited_Controlled with private;
   procedure Reserve
     (Item      : in out Temporary_Directory;
      Prefix    : String;
      Directory : String := "/tmp");
   function Path (Item : Temporary_Directory) return String;

   function Base64 (Text : String) return String;
   procedure Delete_If_Present (Path : String);

private
   Max_Temporary_Path : constant := 4_096;
   type Path_Buffer is record
      Length : Natural range 0 .. Max_Temporary_Path := 0;
      Value  : String (1 .. Max_Temporary_Path) := (others => ASCII.NUL);
   end record;

   type Temporary_File is
     limited new Ada.Finalization.Limited_Controlled with record
      Name : Path_Buffer;
   end record;
   overriding procedure Finalize (Item : in out Temporary_File);

   type Temporary_Directory is
     limited new Ada.Finalization.Limited_Controlled with record
      Name : Path_Buffer;
   end record;
   overriding procedure Finalize (Item : in out Temporary_Directory);
end Test_Support;
