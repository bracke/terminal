with Ada.Real_Time;
with Interfaces;
with Terminal.App.Render_Model;
with Terminal.Core;

package Terminal.App.Image_Store is
   type Animation_Playback_State is
     (Animation_Stopped, Animation_Loading, Animation_Running);

   type Image_Frame;
   type Image_Frame_Access is access Image_Frame;
   type Image_Frame is record
      Number     : Positive := 2;
      Gap_MS     : Integer := 40;
      Usage_Hint : Natural := 0;
      Bytes      : Terminal.App.Render_Model.Image_Data_Access := null;
      Length     : Natural := 0;
      Next       : Image_Frame_Access := null;
   end record;

   type Theme_Operation;
   type Theme_Operation_Access is access Theme_Operation;
   type Theme_Operation is record
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

   type Image_Object;
   type Image_Object_Access is access Image_Object;
   type Image_Object is record
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
      Bytes          : Terminal.App.Render_Model.Image_Data_Access := null;
      Indexed_Format : Natural := 0;
      Indexed_Length : Natural := 0;
      Indexed_Row_Stride_Bytes : Natural := 0;
      Indexed_Bytes  : Terminal.App.Render_Model.Image_Data_Access := null;
      Frames         : Image_Frame_Access := null;
      Frame_Count    : Positive := 1;
      Frame_Bytes    : Natural := 0;
      Theme_Operations : Theme_Operation_Access := null;
      Theme_Operations_Tail : Theme_Operation_Access := null;
      Theme_Operation_Count : Natural := 0;
      Theme_Operation_Bytes : Natural := 0;
      Root_Gap_MS    : Integer := 0;
      Current_Frame  : Positive := 1;
      Playback       : Animation_Playback_State := Animation_Stopped;
      Loop_Count     : Positive := 1;
      Loops_Completed : Natural := 0;
      Next_Frame_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Deadline_Set   : Boolean := False;
      Next           : Image_Object_Access := null;
   end record;

   function Find_By_ID
     (Head      : Image_Object_Access;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Find_By_Number
     (Head      : Image_Object_Access;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Find_By_Storage_Order
     (Head          : Image_Object_Access;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access;

   function Owned_Bytes (Object : Image_Object) return Natural;

   --  Release every allocation owned by Object and restore its defaults.
   procedure Release_Contents (Object : in out Image_Object);

   type Allocation_Control is limited private;

   --  Test seam used to exercise store rollback deterministically.  Zero
   --  disables injection; one rejects the next guarded allocation.
   procedure Fail_Allocation_After
     (Control  : in out Allocation_Control;
      Attempts : Natural);

   function Allocation_Allowed
     (Control : in out Allocation_Control) return Boolean;

   type Install_Transaction is limited private;

   procedure Record_Install
     (Transaction   : in out Install_Transaction;
      Storage_Order : Interfaces.Unsigned_64);
   procedure Commit (Transaction : in out Install_Transaction);
   procedure Take_Rollback_Order
     (Transaction   : in out Install_Transaction;
      Storage_Order : out Interfaces.Unsigned_64);

private
   type Allocation_Control is limited record
      Remaining_Attempts : Natural := 0;
   end record;

   type Install_Transaction is limited record
      Storage_Order : Interfaces.Unsigned_64 := 0;
   end record;
end Terminal.App.Image_Store;
