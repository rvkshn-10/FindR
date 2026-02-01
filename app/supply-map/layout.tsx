import Link from 'next/link'
import { SupplyMapSettingsProvider } from '@/components/supply-map/SupplyMapSettingsProvider'

export const metadata = {
  title: 'Supply Map',
  description: 'Find items nearby – stores, products, and the best option for you.',
}

export default function SupplyMapLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <SupplyMapSettingsProvider>
      <div className="min-h-screen bg-cream-50/30">
        <nav className="border-b border-primary-200 bg-cream-50/90 backdrop-blur-sm sticky top-0 z-50 shadow-sm">
          <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center h-16">
              <Link
                href="/supply-map"
                className="text-xl font-bold text-primary-800 hover:text-primary-900 transition font-serif"
              >
                Supply Map
              </Link>
              <div className="flex items-center gap-6">
                <Link
                  href="/supply-map"
                  className="text-primary-700 hover:text-primary-900 font-medium transition"
                >
                  Search
                </Link>
                <Link
                  href="/supply-map/settings"
                  className="text-primary-600 hover:text-primary-800 text-sm transition"
                >
                  Settings
                </Link>
              </div>
            </div>
          </div>
        </nav>
        <main>{children}</main>
      </div>
    </SupplyMapSettingsProvider>
  )
}
