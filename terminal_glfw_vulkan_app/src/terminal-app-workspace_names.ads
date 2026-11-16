package Terminal.App.Workspace_Names is
   Max_Name_Length : constant := 64;
   type Namespace_Kind is (Named_Layout, Named_Session);

   function Valid_Name (Name : String) return Boolean;

   function Path
     (Kind  : Namespace_Kind;
      Name  : String;
      Valid : out Boolean) return String;
end Terminal.App.Workspace_Names;
