with Ada.Finalization;
with Terminal.App.Owned_Image_Data;

private package Terminal.App.Renderer.Theme_Replay_Storage is
   type Workspace is new Ada.Finalization.Limited_Controlled with private;

   procedure Initialize
     (State        : in out Workspace;
      Maximum_Frame : Positive);

   function Find
     (State  : Workspace;
      Number : Positive)
      return access Terminal.App.Owned_Image_Data.Owner;

   function Insert
     (State  : in out Workspace;
      Number : Positive;
      Source : in out Terminal.App.Owned_Image_Data.Owner)
      return not null access Terminal.App.Owned_Image_Data.Owner;

   type Cursor is private;
   function First (State : Workspace) return Cursor;
   function Has_Element (Position : Cursor) return Boolean;
   procedure Next (Position : in out Cursor);
   function Frame_Number (Position : Cursor) return Positive;
   function Frame_Data
     (Position : Cursor)
      return not null access Terminal.App.Owned_Image_Data.Owner;

private
   type Frame_Node;
   type Frame_Node_Access is access Frame_Node;
   type Frame_Node is limited record
      Number : Positive;
      Bytes  : aliased Terminal.App.Owned_Image_Data.Owner;
      Next   : Frame_Node_Access := null;
   end record;

   type Frame_Index is array (Positive range <>) of Frame_Node_Access;
   type Frame_Index_Access is access Frame_Index;

   type Workspace is new Ada.Finalization.Limited_Controlled with record
      Head  : Frame_Node_Access := null;
      Index : Frame_Index_Access := null;
   end record;
   overriding procedure Finalize (State : in out Workspace);

   type Cursor is record
      Current : Frame_Node_Access := null;
   end record;
end Terminal.App.Renderer.Theme_Replay_Storage;
