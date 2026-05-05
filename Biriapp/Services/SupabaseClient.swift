import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://cgggviihmznmcitwtsoa.supabase.co")!,
    supabaseKey: "sb_publishable_QEmQPLl_9nUtYHff181cDg_Ueu-hdby",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
    )
)
