import SearchBar from '@/components/supply-map/SearchBar'

export default function SupplyMapPage() {
  return (
    <section className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-10 sm:py-16">
      <div className="text-center mb-8 sm:mb-10">
        <h1 className="text-3xl sm:text-4xl font-bold text-primary-900 font-serif tracking-tight mb-2 sm:mb-3">
          What do you need?
        </h1>
        <p className="text-primary-700 text-sm sm:text-base max-w-md mx-auto">
          Find items nearby – we&apos;ll show you stores and the best option.
        </p>
      </div>
      <div className="bg-white rounded-2xl shadow-sm border border-primary-200 p-5 sm:p-6">
        <SearchBar />
      </div>
      <p className="mt-4 text-center text-primary-500 text-xs max-w-md mx-auto">
        We show stores that typically carry this kind of item. Availability is estimated.
      </p>
    </section>
  )
}
