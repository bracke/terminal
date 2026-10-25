with Ada.Real_Time;
with Ada.Finalization;
with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Interfaces;
with System;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.Core;

package Terminal.App.Image_Store is
   use type System.Address;

   type Animation_Playback_State is
     (Animation_Stopped, Animation_Loading, Animation_Running);

   type Image_Frame is tagged private;
   type Image_Frame_Access is access Image_Frame;
   function Number (Frame : Image_Frame) return Positive;
   function Gap_MS (Frame : Image_Frame) return Integer;
   function Usage_Hint (Frame : Image_Frame) return Natural;
   function Bytes
     (Frame : Image_Frame) return Terminal.App.Render_Model.Image_Data_View;
   function Length (Frame : Image_Frame) return Natural;
   procedure Set_Usage_Hint
     (Frame : Image_Frame_Access; Value : Natural);
   procedure Create_Frame
     (Number     : Positive;
      Gap_MS     : Integer;
      Usage_Hint : Natural;
      Data       : in out Terminal.App.Render_Model.Image_Data_Access;
      Frame      : out Image_Frame_Access);
   procedure Append_Unowned_Frame
     (Head, Tail : in out Image_Frame_Access;
      Frame      : in out Image_Frame_Access);
   procedure Release_Unowned_Frames (Head : in out Image_Frame_Access);

   type Theme_Operation is tagged private;
   type Theme_Operation_Access is access Theme_Operation;
   type Theme_Operation_Descriptor is record
      Is_Composition : Boolean := False;
      Archived_Frames : Boolean := False;
      New_Frame      : Boolean := False;
      Target_Frame   : Positive := 1;
      Base_Frame     : Natural := 0;
      Source_Frame   : Natural := 0;
      Raw_Format     : Natural := 32;
      Data_Width     : Natural := 0;
      Data_Height    : Natural := 0;
      Data_Row_Stride_Bytes : Natural := 0;
      Target_X       : Natural := 0;
      Target_Y       : Natural := 0;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Region_Width   : Natural := 0;
      Region_Height  : Natural := 0;
      Composition_Mode : Natural := 0;
      Background_Color : Terminal.Core.Graphics_ID := 0;
   end record;
   function Descriptor
     (Operation : Theme_Operation) return Theme_Operation_Descriptor;
   function Bytes
     (Operation : Theme_Operation)
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
   function Background_Color
     (Operation : Theme_Operation) return Terminal.Core.Graphics_ID;
   procedure Create_Theme_Operation
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Render_Model.Image_Data_Access;
      Operation   : out Theme_Operation_Access);
   procedure Append_Unowned_Theme_Operation
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access);
   procedure Release_Unowned_Theme_Operations
     (Head : in out Theme_Operation_Access);

   type Image_Object is tagged private;
   type Image_Object_Access is access Image_Object;
   type Store is new Ada.Finalization.Limited_Controlled with private;

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
   function Root_Gap_MS (Object : Image_Object) return Integer;
   function Current_Frame (Object : Image_Object) return Positive;
   function Playback (Object : Image_Object) return Animation_Playback_State;
   function Loop_Count (Object : Image_Object) return Positive;
   function Loops_Completed (Object : Image_Object) return Natural;
   function Next_Frame_At (Object : Image_Object) return Ada.Real_Time.Time;
   function Deadline_Set (Object : Image_Object) return Boolean;

   procedure Set_Usage_Hint
     (Object : Image_Object_Access; Value : Natural);
   procedure Set_Root_Gap
     (Object : Image_Object_Access; Value : Integer);
   procedure Set_Current_Frame
     (Object : Image_Object_Access; Value : Positive);
   procedure Set_Playback
     (Object : Image_Object_Access; Value : Animation_Playback_State);
   procedure Set_Loop_Count
     (Object : Image_Object_Access; Value : Positive);
   procedure Set_Loops_Completed
     (Object : Image_Object_Access; Value : Natural);
   procedure Set_Next_Frame_At
     (Object : Image_Object_Access; Value : Ada.Real_Time.Time);
   procedure Set_Deadline
     (Object : Image_Object_Access; Value : Boolean);

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
   function Root_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View;
   function Indexed_Data
     (Object : Image_Object_Access)
      return Terminal.App.Render_Model.Image_Data_View;
   function Indexed_Data_Format
     (Object : Image_Object_Access) return Natural;
   function Indexed_Data_Length
     (Object : Image_Object_Access) return Natural;
   function Indexed_Row_Stride
     (Object : Image_Object_Access) return Natural;
   function First_Frame
     (Object : Image_Object_Access) return Image_Frame_Access;
   function Next_Frame (Frame : Image_Frame_Access) return Image_Frame_Access;
   function Frame_Count_Of (Object : Image_Object_Access) return Positive;
   function First_Theme_Operation
     (Object : Image_Object_Access) return Theme_Operation_Access;
   function Next_Theme_Operation
     (Operation : Theme_Operation_Access) return Theme_Operation_Access;
   function Theme_Operation_Count_Of
     (Object : Image_Object_Access) return Natural;

   function Find_Frame
     (Object : Image_Object_Access;
      Number : Positive) return Image_Frame_Access;
   function Frame_Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean;
   function Frame_Bytes
     (Object : Image_Object_Access;
      Number : Positive)
      return Terminal.App.Render_Model.Image_Data_View;
   function Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive) return Integer;
   function Set_Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive;
      Gap    : Integer) return Boolean;
   procedure Copy_Frame_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean);

   function First (Container : Store) return Image_Object_Access;
   function Next_Object
     (Object : Image_Object_Access) return Image_Object_Access;
   function Object_Count (Container : Store) return Natural;
   function Byte_Count (Container : Store) return Natural;
   function Animation_Frame_Count (Container : Store) return Natural;

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
      Data             : in out Terminal.App.Render_Model.Image_Data_Access);
   procedure Adopt_Indexed_Data
     (Container  : in out Store;
      Object     : Image_Object_Access;
      Format     : Natural;
      Row_Stride : Natural;
      Data       : in out Terminal.App.Render_Model.Image_Data_Access);
   procedure Replace_Root_RGBA
     (Container : in out Store;
      Object    : Image_Object_Access;
      Data      : in out Terminal.App.Render_Model.Image_Data_Access;
      Preserve_Indexed : Boolean := False);
   procedure Append_Frame
     (Container : in out Store;
      Object    : Image_Object_Access;
      Frame     : in out Image_Frame_Access);
   procedure Adopt_Frames
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Image_Frame_Access);
   procedure Replace_Frame_Data
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Data      : in out Terminal.App.Render_Model.Image_Data_Access);
   procedure Clear_Frames
     (Container : in out Store;
      Object    : Image_Object_Access);
   procedure Adopt_Theme_Operations
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Theme_Operation_Access);
   procedure Append_Theme_Operation
     (Container : in out Store;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access);

   --  A theme append may need to precede the corresponding pixel mutation so
   --  allocation failure cannot publish pixels without replay history.  The
   --  transaction owns the appended operation until Commit and removes it on
   --  Rollback.
   type Theme_Append_Transaction is limited private;
   procedure Begin_Theme_Append
     (Container   : aliased in out Store;
      Object      : Image_Object_Access;
      Operation   : in out Theme_Operation_Access;
      Transaction : in out Theme_Append_Transaction);
   procedure Commit (Transaction : in out Theme_Append_Transaction);
   procedure Rollback_Theme_Append
     (Transaction : in out Theme_Append_Transaction);
   procedure Clear_Theme_Operations
     (Container : in out Store;
      Object    : Image_Object_Access);
   procedure Archive_Root_Theme_Operations
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive);
   procedure Delete_Object
     (Container : in out Store;
      Object    : in out Image_Object_Access);
   procedure Delete_Replacement
     (Container : in out Store;
      Object    : in out Image_Object_Access);
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

   type Allocation_Control is limited private;

   function Allocation_Allowed
     (Control : in out Allocation_Control) return Boolean;

private
   type Image_Frame is tagged record
      Number     : Positive := 2;
      Gap_MS     : Integer := 40;
      Usage_Hint : Natural := 0;
      Bytes      : Terminal.App.Render_Model.Image_Data_Access := null;
      Length     : Natural := 0;
      Next       : Image_Frame_Access := null;
   end record;

   type Theme_Operation is tagged record
      Is_Composition : Boolean := False;
      Archived_Frames : Boolean := False;
      New_Frame      : Boolean := False;
      Target_Frame   : Positive := 1;
      Base_Frame     : Natural := 0;
      Source_Frame   : Natural := 0;
      Raw_Format     : Natural := 32;
      Data_Width     : Natural := 0;
      Data_Height    : Natural := 0;
      Data_Row_Stride_Bytes : Natural := 0;
      Target_X       : Natural := 0;
      Target_Y       : Natural := 0;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Region_Width   : Natural := 0;
      Region_Height  : Natural := 0;
      Composition_Mode : Natural := 0;
      Background_Color : Terminal.Core.Graphics_ID := 0;
      Bytes          : Terminal.App.Render_Model.Image_Data_Access := null;
      Length         : Natural := 0;
      Next           : Theme_Operation_Access := null;
   end record;

   function Hash_Address
     (Value : System.Address) return Ada.Containers.Hash_Type;
   package Address_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => System.Address,
      Hash                => Hash_Address,
      Equivalent_Elements => System."=");

   type Image_Object is tagged record
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
      Bytes          : Terminal.App.Render_Model.Image_Data_Access := null;
      Indexed_Format : Natural := 0;
      Indexed_Length : Natural := 0;
      Indexed_Row_Stride_Bytes : Natural := 0;
      Indexed_Bytes  : Terminal.App.Render_Model.Image_Data_Access := null;
      Frames         : Image_Frame_Access := null;
      Frames_Tail    : Image_Frame_Access := null;
      Frame_Count    : Positive := 1;
      Frame_Bytes    : Natural := 0;
      Theme_Operations : Theme_Operation_Access := null;
      Theme_Operations_Tail : Theme_Operation_Access := null;
      Theme_Operation_Count : Natural := 0;
      Theme_Operation_Bytes : Natural := 0;
      Theme_Addresses : Address_Sets.Set;
      Next : Image_Object_Access := null;
      Counted : Boolean := False;
      Replaces : Image_Object_Access := null;
      Accounted_Bytes : Natural := 0;
      Accounted_Frames : Natural := 0;
      Owner : System.Address := System.Null_Address;
   end record;

   type Store is new Ada.Finalization.Limited_Controlled with record
      Head : Image_Object_Access := null;
      Objects : Natural := 0;
      Bytes : Natural := 0;
      Animation_Frames : Natural := 0;
      Next_Storage_Order : Interfaces.Unsigned_64 := 1;
      Next_Content_Serial : Interfaces.Unsigned_64 := 1;
   end record;

   overriding procedure Finalize (Container : in out Store);

   procedure Release_Contents (Object : in out Image_Object);
   procedure Synchronize
     (Container : in out Store;
      Object    : Image_Object_Access);

   type Allocation_Control is limited record
      Remaining_Attempts : Natural := 0;
   end record;

   type Store_Access is access all Store;
   type Theme_Rollback_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Container     : Store_Access := null;
      Object        : Image_Object_Access := null;
      Previous_Tail : Theme_Operation_Access := null;
      Operation     : Theme_Operation_Access := null;
   end record;
   overriding procedure Finalize
     (Guard : in out Theme_Rollback_Guard);
   type Theme_Append_Transaction is limited record
      Guard : Theme_Rollback_Guard;
   end record;
end Terminal.App.Image_Store;
