with Ada.Real_Time;
with Ada.Finalization;
with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Hashed_Maps;
with Interfaces;
with System;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Owned_Image_Data;
with Terminal.Core;

private package Terminal.App.Image_Store is
   use type System.Address;

   type Animation_Playback_State is
     (Animation_Stopped, Animation_Loading, Animation_Running);

   type Image_Frame is tagged limited private;
   type Image_Frame_Access is access Image_Frame;

   type Theme_Operation (Is_Composition : Boolean := False) is
     tagged limited private;
   type Theme_Operation_Access is access Theme_Operation;
   type Theme_Operation_Descriptor
     (Is_Composition : Boolean := False) is record
      Archived_Frames : Boolean := False;
      Target_Frame   : Positive := 1;
      Target_X       : Natural := 0;
      Target_Y       : Natural := 0;
      Composition_Mode : Natural := 0;
      case Is_Composition is
         when False =>
            New_Frame      : Boolean := False;
            Base_Frame     : Natural := 0;
            Raw_Format     : Natural := 32;
            Data_Width     : Natural := 0;
            Data_Height    : Natural := 0;
            Data_Row_Stride_Bytes : Natural := 0;
            Background_Color : Terminal.Core.Graphics_ID := 0;
         when True =>
            Source_Frame   : Positive := 1;
            Source_X       : Natural := 0;
            Source_Y       : Natural := 0;
            Region_Width   : Natural := 0;
            Region_Height  : Natural := 0;
      end case;
   end record;
   --  Operation nodes are opaque construction handles. Read traversal lives
   --  in Image_Store.Themes and is bound to a controlled Data_Borrow.
   type Image_Object is tagged limited private;
   type Image_Object_Access is access Image_Object;
   type Store is new Ada.Finalization.Limited_Controlled with private;
   type Data_Borrow is new Ada.Finalization.Limited_Controlled with private;
   type Delete_Preparation is limited private;

   procedure Create_Object (Object : out Image_Object_Access);
   procedure Release_Unowned_Object (Object : in out Image_Object_Access);

   function Stream_ID (Object : Image_Object) return Terminal.Core.Graphics_Stream_ID;
   function ID (Object : Image_Object) return Terminal.Core.Graphics_ID;
   function Number (Object : Image_Object) return Terminal.Core.Graphics_ID;
   function Protocol
     (Object : Image_Object) return Terminal.App.Render_Model.Image_Protocol;
   function Raw_Format (Object : Image_Object) return Natural;
   function Pixel_Width (Object : Image_Object) return Natural;
   function Pixel_Height (Object : Image_Object) return Natural;
   function Decoded_Length (Object : Image_Object) return Natural;
   function Decoded_Row_Stride_Bytes (Object : Image_Object) return Natural;
   function Usage_Hint (Object : Image_Object) return Natural;
   function Storage_Order (Object : Image_Object) return Interfaces.Unsigned_64;
   function Content_Serial (Object : Image_Object) return Interfaces.Unsigned_64;
   procedure Set_Usage_Hint
     (Container : in out Store;
      Object    : Image_Object_Access;
      Value     : Natural);

   function Find_By_ID
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Find_By_Number
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Find_By_Storage_Order
     (Container     : Store;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access;

   function Owned_Bytes (Object : Image_Object) return Natural;
   function Root_Data_Length (Object : Image_Object_Access) return Natural;
   function Indexed_Data_Allocation_Length
     (Object : Image_Object_Access) return Natural;
   --  Store-backed root, indexed, and animation-frame views are exposed only
   --  while a controlled borrow pins their object. Byte-storage and structural
   --  mutations reject active borrows, and deletion defers reclamation until
   --  the last borrow ends.
   procedure Borrow
     (Item   : in out Data_Borrow;
      Object : Image_Object_Access);
   procedure Release (Item : in out Data_Borrow);
   function Borrowed_Root_Length (Item : Data_Borrow) return Natural;
   function Borrowed_Indexed_Length (Item : Data_Borrow) return Natural;
   procedure Visit_Borrowed_Frame_Data
     (Item   : Data_Borrow;
      Number : Positive;
      Process : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array));
   procedure Copy_Root_Data
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array);
   procedure Copy_Indexed_Data
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array);
   function Indexed_Data_Format
     (Object : Image_Object_Access) return Natural;
   function Indexed_Data_Length
     (Object : Image_Object_Access) return Natural;
   function Indexed_Row_Stride
     (Object : Image_Object_Access) return Natural;

   function First (Container : Store) return Image_Object_Access;
   function Next_Object
     (Object : Image_Object_Access) return Image_Object_Access;
   function Object_Count (Container : Store) return Natural;
   function Byte_Count (Container : Store) return Natural;
   function Animation_Frame_Count (Container : Store) return Natural;

   type Allocation_Control is limited private;

   procedure Link_New
     (Container : in out Store;
      Object    : Image_Object_Access);
   procedure Link_Replacement
     (Container : in out Store;
      Object    : Image_Object_Access;
      Replaced  : Image_Object_Access);
   procedure Install_Root
     (Container        : in out Store;
      Object           : Image_Object_Access;
      Stream_ID        : Terminal.Core.Graphics_Stream_ID;
      ID               : Terminal.Core.Graphics_ID;
      Number           : Terminal.Core.Graphics_ID;
      Protocol         : Terminal.App.Render_Model.Image_Protocol;
      Raw_Format       : Natural;
      Pixel_Width      : Natural;
      Pixel_Height     : Natural;
      Decoded_Length   : Natural;
      Row_Stride       : Natural;
      Usage_Hint       : Natural;
      Data             : in out Terminal.App.Owned_Image_Data.Owner;
      Index_Control    : access Allocation_Control := null);
   procedure Adopt_Indexed_Data
     (Container  : in out Store;
      Object     : Image_Object_Access;
      Format     : Natural;
      Row_Stride : Natural;
      Data       : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Replace_Root_RGBA
     (Container : in out Store;
      Object    : Image_Object_Access;
      Data      : in out Terminal.App.Owned_Image_Data.Owner;
      Preserve_Indexed : Boolean := False;
      Set_Root_Gap : Boolean := False;
      Root_Gap_MS  : Integer := 0;
      Set_Usage    : Boolean := False;
      Usage_Hint   : Natural := 0);
   procedure Delete_Object
     (Container : in out Store;
      Object    : in out Image_Object_Access);
   procedure Delete_Replacement
     (Container : in out Store;
      Object    : in out Image_Object_Access);
   procedure Prepare_Delete_Object
     (Container : Store;
      Object    : Image_Object_Access;
      Preparation : out Delete_Preparation);
   procedure Prepare_Delete_Replacement
     (Container : Store;
      Object    : Image_Object_Access;
      Preparation : out Delete_Preparation);
   procedure Delete_Object
     (Container   : in out Store;
      Object      : in out Image_Object_Access;
      Preparation : in out Delete_Preparation);
   procedure Delete_Replacement
     (Container   : in out Store;
      Object      : in out Image_Object_Access;
      Preparation : in out Delete_Preparation);
   procedure Release_All (Container : in out Store);

   function Allocate_Storage_Order
     (Container : in out Store) return Interfaces.Unsigned_64;
   function Allocate_Content_Serial
     (Container : in out Store) return Interfaces.Unsigned_64;
   procedure Touch
     (Container : in out Store;
      Object    : Image_Object_Access);
   procedure Mark_Content_Changed
     (Container : in out Store;
      Object    : Image_Object_Access);

   function Allocation_Allowed
     (Control : in out Allocation_Control) return Boolean;

private
   function Root_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View;
   function Indexed_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View;
   procedure Assert_Not_Borrowed (Object : Image_Object);
   function Checked_Total (Left, Right : Natural) return Natural;
   procedure Release_Frame_List (Head : in out Image_Frame_Access);
   type Frame_Borrow_Hold is limited record
      Object : Image_Object_Access := null;
      Token  : Interfaces.Unsigned_64 := 0;
   end record;
   procedure Acquire_Frame_Borrow
     (Object : Image_Object_Access;
      Hold   : in out Frame_Borrow_Hold);
   procedure Release_Frame_Borrow (Hold : in out Frame_Borrow_Hold);
   procedure Move_Frame_Borrow
     (Source : in out Frame_Borrow_Hold;
      Target : in out Frame_Borrow_Hold);
   function Is_Owned
     (Container : Store; Object : Image_Object_Access) return Boolean;
   procedure Release_Theme_Operation_List
     (Head : in out Theme_Operation_Access);

   type Image_Frame is tagged limited record
      Number     : Positive := 2;
      Gap_MS     : Integer := 40;
      Usage_Hint : Natural := 0;
      Bytes      : Terminal.App.Owned_Image_Data.Owner;
      Length     : Natural := 0;
      Next       : Image_Frame_Access := null;
   end record;

   type Image_Frame_Index_Array is
     array (Positive range <>) of Image_Frame_Access;
   type Image_Frame_Index_Access is access Image_Frame_Index_Array;

   type Theme_Operation (Is_Composition : Boolean := False) is
     tagged limited record
      Archived_Frames : Boolean := False;
      Target_Frame   : Positive := 1;
      Target_X       : Natural := 0;
      Target_Y       : Natural := 0;
      Composition_Mode : Natural := 0;
      Bytes          : Terminal.App.Owned_Image_Data.Owner;
      Length         : Natural := 0;
      Owner          : Image_Object_Access := null;
      Next           : Theme_Operation_Access := null;
      case Is_Composition is
         when False =>
            New_Frame      : Boolean := False;
            Base_Frame     : Natural := 0;
            Raw_Format     : Natural := 32;
            Data_Width     : Natural := 0;
            Data_Height    : Natural := 0;
            Data_Row_Stride_Bytes : Natural := 0;
            Background_Color : Terminal.Core.Graphics_ID := 0;
         when True =>
            Source_Frame   : Positive := 1;
            Source_X       : Natural := 0;
            Source_Y       : Natural := 0;
            Region_Width   : Natural := 0;
            Region_Height  : Natural := 0;
      end case;
   end record;

   function Hash_Address
     (Value : System.Address) return Ada.Containers.Hash_Type;
   package Address_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => System.Address,
      Hash                => Hash_Address,
      Equivalent_Elements => System."=");

   type Image_Object_State is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      ID             : Terminal.Core.Graphics_ID := 0;
      Number         : Terminal.Core.Graphics_ID := 0;
      Protocol       : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Raw_Format     : Natural := 0;
      Pixel_Width    : Natural := 0;
      Pixel_Height   : Natural := 0;
      Decoded_Length : Natural := 0;
      Decoded_Row_Stride_Bytes : Natural := 0;
      Usage_Hint     : Natural := 0;
      Storage_Order  : Interfaces.Unsigned_64 := 0;
      Content_Serial : Interfaces.Unsigned_64 := 0;
      Root_Gap_MS    : Integer := 0;
      Current_Frame  : Positive := 1;
      Playback       : Animation_Playback_State := Animation_Stopped;
      Loop_Count     : Positive := 1;
      Loops_Completed : Natural := 0;
      Next_Frame_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Deadline_Set   : Boolean := False;
      Indexed_Format : Natural := 0;
      Indexed_Length : Natural := 0;
      Indexed_Row_Stride_Bytes : Natural := 0;
      Frames         : Image_Frame_Access := null;
      Frames_Tail    : Image_Frame_Access := null;
      Frame_Index    : Image_Frame_Index_Access := null;
      Frame_Index_Capacity : Natural := 0;
      Frame_Count    : Positive := 1;
      Frame_Bytes    : Natural := 0;
      Theme_Operations : Theme_Operation_Access := null;
      Theme_Operations_Tail : Theme_Operation_Access := null;
      Theme_Operation_Count : Natural := 0;
      Theme_Operation_Bytes : Natural := 0;
      Theme_Addresses : Address_Sets.Set;
      Theme_Transaction_Active : Boolean := False;
      Theme_Transaction_Quarantined : Boolean := False;
      Frame_Borrows : Natural := 0;
      Borrow_Epoch : Interfaces.Unsigned_64 := 0;
      Pending_Release : Boolean := False;
   end record;

   type Image_Object is tagged limited record
      State          : Image_Object_State;
      Bytes          : Terminal.App.Owned_Image_Data.Owner;
      Indexed_Bytes  : Terminal.App.Owned_Image_Data.Owner;
      Previous : Image_Object_Access := null;
      Next : Image_Object_Access := null;
      ID_Index_Previous : Image_Object_Access := null;
      ID_Index_Next : Image_Object_Access := null;
      Number_Index_Previous : Image_Object_Access := null;
      Number_Index_Next : Image_Object_Access := null;
      Counted : Boolean := False;
      Replaces : Image_Object_Access := null;
      Pending_Replacement : Image_Object_Access := null;
      Accounted_Bytes : Natural := 0;
      Accounted_Frames : Natural := 0;
      Owner : System.Address := System.Null_Address;
   end record;

   type Object_Key is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Value     : Terminal.Core.Graphics_ID;
   end record;
   function Hash_Object_Key
     (Key : Object_Key) return Ada.Containers.Hash_Type;
   package Object_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Object_Key,
      Element_Type    => Image_Object_Access,
      Hash            => Hash_Object_Key,
      Equivalent_Keys => "=");

   type Storage_Key is record
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64;
   end record;
   function Hash_Storage_Key
     (Key : Storage_Key) return Ada.Containers.Hash_Type;
   package Storage_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Storage_Key,
      Element_Type    => Image_Object_Access,
      Hash            => Hash_Storage_Key,
      Equivalent_Keys => "=");

   type Allocation_Control is limited record
      Remaining_Attempts : Natural := 0;
   end record;

   type Store is new Ada.Finalization.Limited_Controlled with record
      Head : Image_Object_Access := null;
      Objects : Natural := 0;
      Bytes : Natural := 0;
      Animation_Frames : Natural := 0;
      Next_Storage_Order : Interfaces.Unsigned_64 := 1;
      Next_Content_Serial : Interfaces.Unsigned_64 := 1;
      Mutation_Epoch : Interfaces.Unsigned_64 := 1;
      By_ID : Object_Maps.Map;
      By_Number : Object_Maps.Map;
      By_Storage_Order : Storage_Maps.Map;
   end record;

   type Delete_Preparation is limited record
      Store_Address          : System.Address := System.Null_Address;
      Object                 : Image_Object_Access := null;
      Previous               : Image_Object_Access := null;
      Replacement_To_Promote : Image_Object_Access := null;
      Counted                : Boolean := False;
      Mutation_Epoch         : Interfaces.Unsigned_64 := 0;
      Valid                  : Boolean := False;
   end record;

   overriding procedure Finalize (Container : in out Store);

   type Data_Borrow is new Ada.Finalization.Limited_Controlled with record
      Hold : Frame_Borrow_Hold;
   end record;
   overriding procedure Finalize (Item : in out Data_Borrow);

   procedure Release_Contents (Object : in out Image_Object);
   function Owns_Data_View
     (Object : Image_Object_Access;
      Data   : Terminal.App.Render_Model.Image_Data_View) return Boolean;
   procedure Advance_Mutation_Epoch (Container : in out Store);
   procedure Synchronize
     (Container : in out Store;
      Object    : Image_Object_Access);
end Terminal.App.Image_Store;
