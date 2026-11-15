with Ada.Unchecked_Deallocation;

package body Terminal.App.Renderer.Theme_Replay_Storage is
   procedure Free_Node is new Ada.Unchecked_Deallocation
     (Frame_Node, Frame_Node_Access);
   procedure Free_Index is new Ada.Unchecked_Deallocation
     (Frame_Index, Frame_Index_Access);

   procedure Initialize
     (State         : in out Workspace;
      Maximum_Frame : Positive) is
   begin
      if State.Index /= null or else State.Head /= null then
         raise Program_Error with "theme replay workspace is already initialized";
      end if;
      State.Index := new Frame_Index (1 .. Maximum_Frame);
      State.Index.all := (others => null);
   end Initialize;

   function Find
     (State  : Workspace;
      Number : Positive)
      return access Terminal.App.Owned_Image_Data.Owner is
   begin
      if State.Index = null
        or else Number > State.Index'Last
        or else State.Index (Number) = null
      then
         return null;
      end if;
      return State.Index (Number).Bytes'Access;
   end Find;

   function Insert
     (State  : in out Workspace;
      Number : Positive;
      Source : in out Terminal.App.Owned_Image_Data.Owner)
      return not null access Terminal.App.Owned_Image_Data.Owner
   is
      Item : Frame_Node_Access := null;
   begin
      if State.Index = null or else Number > State.Index'Last then
         raise Constraint_Error with "theme replay frame is outside workspace";
      elsif State.Index (Number) /= null then
         raise Program_Error with "theme replay frame is already present";
      end if;

      Item := new Frame_Node'(Number => Number, Bytes => <>, Next => State.Head);
      Terminal.App.Owned_Image_Data.Move (Source, Item.Bytes);
      State.Head := Item;
      State.Index (Number) := Item;
      return Item.Bytes'Access;
   end Insert;

   function First (State : Workspace) return Cursor is
     ((Current => State.Head));

   function Has_Element (Position : Cursor) return Boolean is
     (Position.Current /= null);

   procedure Next (Position : in out Cursor) is
   begin
      if Position.Current = null then
         raise Constraint_Error with "theme replay cursor has no element";
      end if;
      Position.Current := Position.Current.Next;
   end Next;

   function Frame_Number (Position : Cursor) return Positive is
   begin
      if Position.Current = null then
         raise Constraint_Error with "theme replay cursor has no element";
      end if;
      return Position.Current.Number;
   end Frame_Number;

   function Frame_Data
     (Position : Cursor)
      return not null access Terminal.App.Owned_Image_Data.Owner is
   begin
      if Position.Current = null then
         raise Constraint_Error with "theme replay cursor has no element";
      end if;
      return Position.Current.Bytes'Access;
   end Frame_Data;

   overriding procedure Finalize (State : in out Workspace) is
      Current : Frame_Node_Access := State.Head;
   begin
      State.Head := null;
      while Current /= null loop
         declare
            Following : constant Frame_Node_Access := Current.Next;
         begin
            Free_Node (Current);
            Current := Following;
         end;
      end loop;
      Free_Index (State.Index);
   end Finalize;
end Terminal.App.Renderer.Theme_Replay_Storage;
