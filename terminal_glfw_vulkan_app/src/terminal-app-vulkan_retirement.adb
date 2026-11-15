package body Terminal.App.Vulkan_Retirement is
   function Evaluate
     (Fence             : Fence_Outcome;
      Cleanup_Succeeded : Boolean) return Retirement_Outcome
   is
   begin
      case Fence is
         when Fence_Ready =>
            return
              (if Cleanup_Succeeded then Retired else Cleanup_Failed);
         when Fence_In_Flight =>
            return Still_In_Flight;
         when Fence_Device_Lost =>
            return Device_Lost;
         when Fence_Failed =>
            return Fence_Failed;
      end case;
   end Evaluate;

   function Classify_Fence_Restore
     (Succeeded   : Boolean;
      Device_Lost : Boolean) return Fence_Restore_Outcome is
     (if Succeeded then Fence_Restored
      elsif Device_Lost then Fence_Restore_Device_Lost
      else Fence_Restore_Failed);
end Terminal.App.Vulkan_Retirement;
