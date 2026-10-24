with Ada.Streams;
with GNAT.OS_Lib;

package Terminal_Tools is
   function Repository_Root return String;
   function Path (Directory, Name : String) return String;
   function Locate_Executable (Name : String) return String;
   function Current_Executable return String;
   function Shell_Quote (Value : String) return String;

   function Run
     (Program     : String;
      Args        : GNAT.OS_Lib.Argument_List;
      Output_File : String := "";
      Err_To_Out  : Boolean := True) return Integer;

   function Read_File (Name : String) return String;
   function Read_First_Line (Name : String) return String;
   function File_Contains (Name, Pattern : String) return Boolean;
   function File_Has_Line (Name, Expected : String) return Boolean;
   procedure Write_Bytes
     (Name : String;
      Data : Ada.Streams.Stream_Element_Array);

   function Create_Work_Directory (Prefix : String) return String;
   procedure Remove_Work_Directory (Name : String);
end Terminal_Tools;
