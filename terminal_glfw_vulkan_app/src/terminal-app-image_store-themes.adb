package body Terminal.App.Image_Store.Themes is
   function Descriptor
     (Operation : Theme_Operation) return Theme_Operation_Descriptor is
     (Terminal.App.Image_Store.Descriptor (Operation));
   function Bytes (Operation : Theme_Operation)
     return Terminal.App.Render_Model.Image_Data_View is
     (Terminal.App.Image_Store.Bytes (Operation));
   function Length (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Length (Operation));
   function Is_Composition (Operation : Theme_Operation) return Boolean is
     (Terminal.App.Image_Store.Is_Composition (Operation));
   function Archived_Frames (Operation : Theme_Operation) return Boolean is
     (Terminal.App.Image_Store.Archived_Frames (Operation));
   function New_Frame (Operation : Theme_Operation) return Boolean is
     (Terminal.App.Image_Store.New_Frame (Operation));
   function Target_Frame (Operation : Theme_Operation) return Positive is
     (Terminal.App.Image_Store.Target_Frame (Operation));
   function Base_Frame (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Base_Frame (Operation));
   function Source_Frame (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Source_Frame (Operation));
   function Raw_Format (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Raw_Format (Operation));
   function Data_Width (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Data_Width (Operation));
   function Data_Height (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Data_Height (Operation));
   function Data_Row_Stride_Bytes
     (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Data_Row_Stride_Bytes (Operation));
   function Target_X (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Target_X (Operation));
   function Target_Y (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Target_Y (Operation));
   function Source_X (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Source_X (Operation));
   function Source_Y (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Source_Y (Operation));
   function Region_Width (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Region_Width (Operation));
   function Region_Height (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Region_Height (Operation));
   function Composition_Mode (Operation : Theme_Operation) return Natural is
     (Terminal.App.Image_Store.Composition_Mode (Operation));
   function Background_Color (Operation : Theme_Operation)
     return Terminal.Core.Graphics_ID is
     (Terminal.App.Image_Store.Background_Color (Operation));

   procedure Create
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Render_Model.Image_Data_Access;
      Operation   : out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Create_Theme_Operation
        (Description, Data, Operation);
   end Create;
   procedure Append_Unowned
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Append_Unowned_Theme_Operation
        (Head, Tail, Operation);
   end Append_Unowned;
   procedure Release_Unowned (Head : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Release_Unowned_Theme_Operations (Head);
   end Release_Unowned;
   function First (Object : Image_Object_Access)
     return Theme_Operation_Access is
     (Terminal.App.Image_Store.First_Theme_Operation (Object));
   function Next (Operation : Theme_Operation_Access)
     return Theme_Operation_Access is
     (Terminal.App.Image_Store.Next_Theme_Operation (Operation));
   function Count (Object : Image_Object_Access) return Natural is
     (Terminal.App.Image_Store.Theme_Operation_Count_Of (Object));
   procedure Adopt
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Adopt_Theme_Operations
        (Container, Object, Head);
   end Adopt;
   procedure Append
     (Container : in out Store;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Append_Theme_Operation
        (Container, Object, Operation);
   end Append;
   procedure Clear
     (Container : in out Store; Object : Image_Object_Access) is
   begin
      Terminal.App.Image_Store.Clear_Theme_Operations (Container, Object);
   end Clear;
   procedure Archive_Root
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive) is
   begin
      Terminal.App.Image_Store.Archive_Root_Theme_Operations
        (Container, Object, Max_Operations);
   end Archive_Root;
end Terminal.App.Image_Store.Themes;
