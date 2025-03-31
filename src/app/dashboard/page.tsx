'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function Dashboard() {
  const router = useRouter()

  useEffect(() => {
    // Redirect to profile page
    router.replace('/dashboard/profile')
  }, [router])

  return (
    <div className="flex items-center justify-center h-full">
      <div className="text-white">Redirecting to profile...</div>
    </div>
  )
} 