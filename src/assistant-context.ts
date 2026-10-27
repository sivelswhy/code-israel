import { createContext, useContext } from 'react'
import type { Question } from './data'

export interface AssistantTopic {
  question: Question
  chosen?: number | null
}

/** Opens the assistant, optionally about a given question. */
export const AssistantContext = createContext<(topic?: AssistantTopic) => void>(() => {})

export const useAssistant = () => useContext(AssistantContext)
