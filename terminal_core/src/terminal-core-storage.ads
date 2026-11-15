private package Terminal.Core.Storage is
   procedure Release (Value : in out Stored_Cell_Array_Access);
   procedure Release (Value : in out Snapshot_Cell_Array_Access);
   procedure Release (Value : in out Snapshot_Link_Array_Access);
   procedure Release (Value : in out Dirty_Row_Array_Access);
   procedure Release (Value : in out Graphics_Scroll_Event_Array_Access);
   procedure Release (Value : in out Tab_Stop_Array_Access);
   procedure Release (Value : in out String_Access);
   procedure Release (Value : in out Core_Byte_Array_Access);
end Terminal.Core.Storage;
