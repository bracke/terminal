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
end Terminal.App.Vulkan_Retirement;
