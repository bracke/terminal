package Terminal.App.Image_Store.Themes is
   function Descriptor
     (Operation : Theme_Operation) return Theme_Operation_Descriptor;
   function Bytes (Operation : Theme_Operation)
     return Terminal.App.Render_Model.Image_Data_View;
   function Length (Operation : Theme_Operation) return Natural;
   function Is_Composition (Operation : Theme_Operation) return Boolean;
   function Archived_Frames (Operation : Theme_Operation) return Boolean;
   function New_Frame (Operation : Theme_Operation) return Boolean;
   function Target_Frame (Operation : Theme_Operation) return Positive;
   function Base_Frame (Operation : Theme_Operation) return Natural;
   function Source_Frame (Operation : Theme_Operation) return Natural;
   function Raw_Format (Operation : Theme_Operation) return Natural;
   function Data_Width (Operation : Theme_Operation) return Natural;
   function Data_Height (Operation : Theme_Operation) return Natural;
   function Data_Row_Stride_Bytes (Operation : Theme_Operation) return Natural;
   function Target_X (Operation : Theme_Operation) return Natural;
   function Target_Y (Operation : Theme_Operation) return Natural;
   function Source_X (Operation : Theme_Operation) return Natural;
   function Source_Y (Operation : Theme_Operation) return Natural;
   function Region_Width (Operation : Theme_Operation) return Natural;
   function Region_Height (Operation : Theme_Operation) return Natural;
   function Composition_Mode (Operation : Theme_Operation) return Natural;
   function Background_Color (Operation : Theme_Operation)
     return Terminal.Core.Graphics_ID;
   procedure Create
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Render_Model.Image_Data_Access;
      Operation   : out Theme_Operation_Access);
   procedure Append_Unowned
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access);
   procedure Release_Unowned (Head : in out Theme_Operation_Access);
   function First (Object : Image_Object_Access)
     return Theme_Operation_Access;
   function Next (Operation : Theme_Operation_Access)
     return Theme_Operation_Access;
   function Count (Object : Image_Object_Access) return Natural;
   procedure Adopt
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Theme_Operation_Access);
   procedure Append
     (Container : in out Store;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access);
   procedure Clear (Container : in out Store; Object : Image_Object_Access);
   procedure Archive_Root
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive);
end Terminal.App.Image_Store.Themes;
