with Ada.Unchecked_Deallocation;

package body Terminal.Core.Storage is
   procedure Release_Cells is new Ada.Unchecked_Deallocation
     (Stored_Cell_Array, Stored_Cell_Array_Access);
   procedure Release_Snapshot_Cells is new Ada.Unchecked_Deallocation
     (Snapshot_Cell_Array, Snapshot_Cell_Array_Access);
   procedure Release_Snapshot_Links is new Ada.Unchecked_Deallocation
     (Snapshot_Link_Array, Snapshot_Link_Array_Access);
   procedure Release_Dirty is new Ada.Unchecked_Deallocation
     (Dirty_Row_Array, Dirty_Row_Array_Access);
   procedure Release_Scroll_Events is new Ada.Unchecked_Deallocation
     (Graphics_Scroll_Event_Array, Graphics_Scroll_Event_Array_Access);
   procedure Release_Tab_Stops is new Ada.Unchecked_Deallocation
     (Tab_Stop_Array, Tab_Stop_Array_Access);
   procedure Release_String is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Release_Bytes is new Ada.Unchecked_Deallocation
     (Core_Byte_Array, Core_Byte_Array_Access);

   procedure Release (Value : in out Stored_Cell_Array_Access) is
   begin
      Release_Cells (Value);
   end Release;

   procedure Release (Value : in out Snapshot_Cell_Array_Access) is
   begin
      Release_Snapshot_Cells (Value);
   end Release;

   procedure Release (Value : in out Snapshot_Link_Array_Access) is
   begin
      Release_Snapshot_Links (Value);
   end Release;

   procedure Release (Value : in out Dirty_Row_Array_Access) is
   begin
      Release_Dirty (Value);
   end Release;

   procedure Release (Value : in out Graphics_Scroll_Event_Array_Access) is
   begin
      Release_Scroll_Events (Value);
   end Release;

   procedure Release (Value : in out Tab_Stop_Array_Access) is
   begin
      Release_Tab_Stops (Value);
   end Release;

   procedure Release (Value : in out String_Access) is
   begin
      Release_String (Value);
   end Release;

   procedure Release (Value : in out Core_Byte_Array_Access) is
   begin
      Release_Bytes (Value);
   end Release;
end Terminal.Core.Storage;
